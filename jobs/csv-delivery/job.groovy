import groovy.json.JsonSlurper
import java.nio.file.Files

parameter('submissionId', required: true, description: 'UUID der Submission')
parameter('inputFile', type: 'path', required: true, description: 'Private Eingabe-CSV')
parameter('adminUrl', required: true, description: 'URL der internen Delivery-API')
parameter('tokenUrl', required: true, description: 'Keycloak-Token-Endpunkt')
parameter('localHttp', type: 'boolean', defaultValue: false, description: 'HTTP im lokalen Stack erlauben')
parameter('s3Endpoint', required: true, description: 'Garage-Endpunkt')
parameter('s3AccessKey', required: true, description: 'Garage Writer Access Key')
parameter('s3Bucket', defaultValue: 'ch.so.daten', description: 'Privater Garage-Bucket')
parameter('clickhouseUrl', required: true, description: 'ClickHouse-HTTP-Endpunkt')
parameter('clickhouseUser', required: true, description: 'ClickHouse-Importbenutzer')

def deliveryUrl = { adminUrl, localHttp, submissionId, operation ->
    def base = URI.create(adminUrl)
    if (base.scheme != 'https' && !(localHttp && base.scheme == 'http')) {
        throw new IllegalArgumentException('Die Admin-API benötigt HTTPS.')
    }
    "${base}/${UUID.fromString(submissionId)}/${operation}"
}
def table = { submissionId -> 'snapshot_' + UUID.fromString(submissionId).toString().replace('-', '') }
def sqlPath = { path -> "'" + path.toString().replace("'", "''") + "'" }

def clickhouseColumn = { column ->
    if (!(column.name ==~ /[A-Za-z][A-Za-z0-9_]{0,62}/)) {
        throw new IllegalArgumentException('Ungültiger CSV-Spaltenname.')
    }
    String type = switch (column.dataType) {
        case 'text', 'mtext', 'enumeration' -> 'String'
        case 'integer' -> 'Int64'
        case 'decimal' -> "Decimal(38, ${column.decimalPlaces as int})"
        case 'boolean' -> 'Bool'
        case 'date' -> 'Date32'
        case 'datetime' -> "DateTime64(3, 'UTC')"
        default -> throw new IllegalArgumentException('Unbekannter CSV-Datentyp.')
    }
    "`${column.name}` ${column.mandatory ? type : "Nullable(${type})"}"
}

task('authorizeStart', OAuth2ClientCredentials) {
    tokenUrl = parameter('tokenUrl')
    clientId = 'gretl-delivery'
    clientSecret = secret('oauthClientSecret')
    allowInsecureHttp = parameter('localHttp')
}

task('start', Curl, dependsOn: 'authorizeStart') {
    serverUrl = deliveryUrl(parameter('adminUrl'), parameter('localHttp'), parameter('submissionId'), 'start')
    method = 'POST'
    expectedStatusCode = 200
    headers = ['Authorization': result('authorizeStart').authorization]
    outputFile = workPath('start.json')
}

['mode', 'schemaModelName', 'baseCsvKey', 'candidatePrefix', 'columns'].each { field ->
    task(field, JsonRead, dependsOn: 'start') {
        sourceFile = result('start').outputFile
        pointer = '/' + field
    }
}

task('downloadModel', Curl, dependsOn: 'schemaModelName') {
    serverUrl = deliveryUrl(parameter('adminUrl'), parameter('localHttp'), parameter('submissionId'), 'model.ili')
    expectedStatusCode = 200
    headers = ['Authorization': result('authorizeStart').authorization]
    outputFile = workPath(result('schemaModelName').value + '.ili')
}

task('downloadBase', S3Download, dependsOn: ['mode', 'baseCsvKey'], when: {
    result('mode').value == 'append'
}) {
    accessKey = parameter('s3AccessKey')
    secretKey = secret('s3SecretKey')
    endpoint = parameter('s3Endpoint')
    region = 'garage'
    bucketName = parameter('s3Bucket')
    def baseKey = result('baseCsvKey').value
    if (!baseKey) throw new IllegalArgumentException('Die Append-Basis fehlt.')
    key = baseKey
    downloadDir = workPath('base')
}

task('append', DuckDbSqlExecutor, dependsOn: 'downloadBase', when: {
    result('mode').value == 'append'
}) {
    inMemory = true
    sqlFiles = [file('append.sql')]
    sqlParameters = [
        base: sqlPath(result('downloadBase').files.first()),
        incoming: sqlPath(parameter('inputFile')),
        snapshot: sqlPath(parameter('inputFile').resolveSibling('snapshot.csv'))
    ]
}

def snapshot = { mode, input ->
    mode == 'append' ? input.resolveSibling('snapshot.csv') : input
}

task('validate', CsvValidator, dependsOn: ['append', 'downloadModel']) {
    dataFiles = [snapshot(result('mode').value, parameter('inputFile'))]
    modelNames = [result('schemaModelName').value]
    modelDirectories = [result('downloadModel').outputFile.parent]
    firstLineIsHeader = true
    valueSeparator = ','
    valueDelimiter = '"'
    encoding = 'UTF-8'
    logFile = workPath('validation.log')
    failOnError = false
}

task('reject', Curl, dependsOn: 'validate', when: { !result('validate').valid }) {
    serverUrl = deliveryUrl(parameter('adminUrl'), parameter('localHttp'), parameter('submissionId'), 'reject')
    method = 'POST'
    expectedStatusCode = 200
    headers = ['Authorization': result('authorizeStart').authorization, 'Content-Type': 'application/json']
    data = '{"message":"Der CSV-Snapshot verletzt das gebundene Modell."}'
}

task('createTable', SqlExecutor, dependsOn: ['validate', 'columns'], when: { result('validate').valid }) {
    database = 'clickhouse'
    def columns = new JsonSlurper().parseText(result('columns').value).collect(clickhouseColumn).join(', ')
    statements = [[sql: "CREATE TABLE default.${table(parameter('submissionId'))} (${columns}) ENGINE = MergeTree ORDER BY tuple()".toString(),
                   parameters: []]]
}

task('importCsv', CsvImport, dependsOn: 'createTable', when: {
    result('validate').valid && Files.newBufferedReader(snapshot(result('mode').value, parameter('inputFile'))).withCloseable { reader ->
        reader.readLine()
        reader.read() != -1
    }
}) {
    database = 'clickhouse'
    schemaName = 'default'
    tableName = table(parameter('submissionId'))
    dataFile = snapshot(result('mode').value, parameter('inputFile'))
    firstLineIsHeader = true
    valueSeparator = ','
    valueDelimiter = '"'
    encoding = 'UTF-8'
}

task('upload', S3Upload, dependsOn: ['importCsv', 'candidatePrefix'], when: { result('validate').valid }) {
    accessKey = parameter('s3AccessKey')
    secretKey = secret('s3SecretKey')
    endpoint = parameter('s3Endpoint')
    region = 'garage'
    bucketName = parameter('s3Bucket')
    sourceFile = snapshot(result('mode').value, parameter('inputFile'))
    key = result('candidatePrefix').value + 'snapshot.csv'
    acl = 'private'
    contentType = 'text/csv'
}

task('count', Curl, dependsOn: 'upload', when: { result('validate').valid }) {
    serverUrl = parameter('clickhouseUrl')
    method = 'POST'
    expectedStatusCode = 200
    user = parameter('clickhouseUser')
    password = secret('clickhousePassword')
    data = "SELECT count() AS objectCount FROM default.${table(parameter('submissionId'))} FORMAT JSONEachRow"
    outputFile = workPath('count.json')
}

task('readCount', JsonRead, dependsOn: 'count', when: { result('validate').valid }) {
    sourceFile = result('count').outputFile
    pointer = '/objectCount'
}

task('authorizeComplete', OAuth2ClientCredentials, dependsOn: 'readCount', when: { result('validate').valid }) {
    tokenUrl = parameter('tokenUrl')
    clientId = 'gretl-delivery'
    clientSecret = secret('oauthClientSecret')
    allowInsecureHttp = parameter('localHttp')
}

task('complete', Curl, dependsOn: 'authorizeComplete', when: { result('validate').valid }) {
    serverUrl = deliveryUrl(parameter('adminUrl'), parameter('localHttp'), parameter('submissionId'), 'complete')
    method = 'POST'
    expectedStatusCode = 200
    headers = ['Authorization': result('authorizeComplete').authorization, 'Content-Type': 'application/json']
    data = '{"objectCount":' + Long.parseLong(result('readCount').value) + '}'
}

defaults 'reject', 'complete'

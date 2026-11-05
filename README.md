# Jenkins-Laufzeit für die Dateninfrastruktur

Jenkins läuft im gemeinsamen Compose-Projekt des Schwesterrepositories
`dateninfrastruktur-dev-stack`. Dessen `services/jenkins/jenkins-stack.yaml`
ist die gemeinsame JCasC-Quelle. Sie bindet Keycloak, das Plugin
`jenkins-gretl-dateninfrastruktur-plugin` und die internen Admin-Endpunkte.

Für einen lokalen Kandidaten aus den sechs zusammengehörigen Checkouts:

```sh
IMAGE_NAME=dateninfrastruktur-jenkins:mein-kandidat ./bin/build-image.sh <neues-kontextverzeichnis>
```

Der Build benötigt Java 21, Maven, Docker mit Buildx sowie das in MA-G0
identifizierte, lokal vorhandene GRETL-Toolchain-Image. Er baut das HPI aus
dem Schwestercheckout, prüft die GRETL-JARs und das gepinnte OIDC-HPI per
SHA256 und kopiert die versionierten Modelle und Verträge als schreibgeschütztes
Bundle ins Image. Für GRETL enthält das Image Java 17. Buildargumente und
HPI-Hash stehen im erzeugten Kontext. Ein bereits erzeugter Kontext lässt sich
mit `./bin/build-image.sh --prepared-context <kontext>` erneut bauen.

Der Stack verwendet ein persistentes Jenkins-Home. Bei einer Migration wird
Jenkins zuerst gestoppt; der im Dev-Stack dokumentierte Offline-Schritt
archiviert die anhand ihrer Jobproperty identifizierten Altjobs samt Historie.
Fremde Jobs und das Home bleiben erhalten. Ein frischer Start erzeugt
`di-csv-ingest`, die Anlieferung ist unter `/anlieferung` erreichbar.

Der frühere Multiarch-Publikationsablauf ist im
[historischen Workflow](docs/historical/publish-docker-image-ma-f.yml)
dokumentiert. Er verwendete ein anderes Toolchain- und Installationsverfahren.
MA-G liefert den geprüften lokalen Kandidatenbuild; es wird kein neuer
Release- oder CI-Ablauf eingerichtet.

# Jenkins-Laufzeit für die Dateninfrastruktur

Jenkins läuft mit Java 21 im gemeinsamen Compose-Projekt. Der Dev-Stack
liefert die JCasC-Konfiguration für Keycloak, Admin und die technischen
Credentials. Das Plugin aus dem Schwestercheckout stellt die
CSV-Anlieferung bereit und startet den festen Job.

```sh
IMAGE_NAME=dateninfrastruktur-jenkins:mein-kandidat ./bin/build-image.sh <neues-kontextverzeichnis>
```

Der Build benötigt Java 21, Maven und Docker Buildx. Gradle löst
`ch.so.agi.gretl:gretl-dist:6.0.0-SNAPSHOT:bin@zip` aus dem
Maven-Snapshot-Repository `https://jars.interlis.guru/snapshots` auf.
Das Image installiert die Distribution unter `/opt/gretl` und ergänzt den
ClickHouse-JDBC-Treiber. Für eine Aktualisierung den Image-Build erneut ausführen.

Jenkins startet `/opt/gretl/bin/gretl run /opt/dateninfrastruktur/csv-delivery/job.groovy`
mit Java 25, einer Parameterdatei und privaten Laufzeit-Credentials.
GRETL holt einen technischen Token und das gebundene INTERLIS-Modell von Admin.
Replace verwendet die Eingabedatei. Append lädt den bisherigen CSV-Snapshot und
fügt neue Zeilen mit DuckDB an. GRETL validiert den vollständigen Snapshot,
schreibt ihn in ClickHouse und Garage und meldet die Zeilenzahl an Admin.
Admin entscheidet über die Annahme.

Den gezielten Reject-Test mit der veröffentlichten Distribution ausführen:

```sh
JAVA_HOME=<Java-25-Verzeichnis> python3 tests/test_delivery_reject.py <GRETL-Verzeichnis>/bin/gretl
```

Den Image-Build und den Ablauf im
[isolierten Compose-Test](../dateninfrastruktur-dev-stack/docs/operations.md#csv-anlieferung-mit-gretl-6)
prüfen.

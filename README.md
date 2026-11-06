# Jenkins-Laufzeit für die Dateninfrastruktur

Jenkins läuft im gemeinsamen Compose-Projekt des Schwesterrepositories
`dateninfrastruktur-dev-stack`. Dessen `services/jenkins/jenkins-stack.yaml`
ist die gemeinsame JCasC-Quelle. Sie bindet Keycloak, das Plugin
`jenkins-gretl-dateninfrastruktur-plugin` und die internen Admin-Endpunkte.

Für einen lokalen Kandidaten aus den sechs zusammengehörigen Checkouts:

```sh
IMAGE_NAME=dateninfrastruktur-jenkins:mein-kandidat ./bin/build-image.sh <neues-kontextverzeichnis>
```

Der Build benötigt Java 21, Maven, Docker mit Buildx sowie das lokal vorhandene, im [Toolchain-Lock](toolchain-lock.json) gebundene GRETL-Image. Er baut das HPI aus
dem Schwestercheckout, prüft die GRETL-JARs und das gepinnte OIDC-HPI per
SHA256 und kopiert die versionierten Modelle und Verträge als schreibgeschütztes
Bundle ins Image. Für GRETL enthält das Image Java 17. Buildargumente und
HPI-Hash stehen im erzeugten Kontext. Ein bereits erzeugter Kontext lässt sich
mit `./bin/build-image.sh --prepared-context <kontext>` erneut bauen.

Der Stack verwendet ein persistentes Jenkins-Home. Der generische
Job `di-csv-ingest` verarbeitet gebundene Lieferpläne. Die Anlieferung ist
unter `/anlieferung` erreichbar. Die Betriebsbefehle stehen im
[Compose-Betrieb](../dateninfrastruktur-dev-stack/docs/operations.md).

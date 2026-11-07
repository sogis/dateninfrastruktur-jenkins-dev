# Jenkins-Laufzeit für die Dateninfrastruktur

Jenkins läuft im gemeinsamen Compose-Projekt des Schwesterrepositories
`dateninfrastruktur-dev-stack`. Dessen `services/jenkins/jenkins-stack.yaml`
ist die gemeinsame JCasC-Quelle. Sie bindet Keycloak, das Plugin
`jenkins-gretl-dateninfrastruktur-plugin` und die internen Admin-Endpunkte.

Für einen lokalen Kandidaten aus den sechs zusammengehörigen Checkouts:

```sh
IMAGE_NAME=dateninfrastruktur-jenkins:mein-kandidat ./bin/build-image.sh <neues-kontextverzeichnis>
```

Der Build benötigt Java 21, Maven und Docker mit Buildx. Er ermittelt das
aktuelle GRETL-5-Snapshot aus dem Maven-Repository, löst dessen Laufzeit-JARs
auf und nimmt sie zusammen mit den DuckDB-Erweiterungen als geprüftes
Offline-Bundle ins Image auf. Der Build dokumentiert die konkrete
Snapshot-Version und die SHA-256-Prüfsummen. Das HPI kommt aus dem
Schwestercheckout. Modelle, Verträge und Runner liegen schreibgeschützt im
Image. GRETL läuft mit Java 17.

Der Stack verwendet ein persistentes Jenkins-Home. Der generische
Job `di-csv-ingest` verarbeitet gebundene Lieferpläne. Die Anlieferung ist
unter `/anlieferung` erreichbar. Die Betriebsbefehle stehen im
[Compose-Betrieb](../dateninfrastruktur-dev-stack/docs/operations.md).

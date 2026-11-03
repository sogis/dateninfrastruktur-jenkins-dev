# dateninfrastruktur-jenkins-dev

Lokales Jenkins-Controller- und Integrationsrepo für die Dateninfrastruktur-Grundinstallation. Es baut das Jenkins-Image aus dem neuen Plugin- und Themenrepo; ein Quell-`jenkins-home/` wird nicht übernommen.

## Rolle im Gesamtsystem

Dieses Repo ist die technische Laufzeitumgebung fuer lokale Entwicklung und
Offline-Tests.

Hierher gehoeren:

- lokaler Jenkins-Controller, `casc/jenkins.yaml` und `plugins.txt`
- Offline-Bundle fuer GRETL, Gradle-Wrapper und Plugin-Runtimes
- Plugin-Installations- und Restart-Loop fuer lokales Testen
- Docker-Image fuer reproduzierbare Jenkins- und Airgap-Tests

Nicht hierher gehoeren:

- der fachliche Vertrag des Themenrepos:
  [dateninfrastruktur-themenrepo](https://github.com/sogis/dateninfrastruktur-themenrepo)
- die Implementierung des Jenkins-Plugins:
  [dateninfrastruktur-jenkins-gretl-plugin](https://github.com/sogis/dateninfrastruktur-jenkins-gretl-plugin)

## Zentrale Workflows

Die folgenden Befehle betreffen den separaten Shellstart von Jenkins. Für das
Gesamtsystem mit Garage, Editor und Portal gilt die
[Dev-Stack-Inbetriebnahme](https://github.com/sogis/dateninfrastruktur-dev-stack/src/branch/main/docs/biblios/inbetriebnahme.adoc).
Dort bereitet `scripts/up.sh` den Stack vollständig vor, einschliesslich
erfolgreichem Seed, lokaler Erstpublikation und Portalstart. Die gemeinsame
Stack-Test-JCasC liegt im Dev-Stack; dieser Jenkins-Quellcheckout ist dort nur
für lokale Image-Builds erforderlich. Pluginersatz und administrativer
Migrationsweg bleiben ebenfalls dort beschrieben. `working-tree` verhindert Git-Schreiben; S3 ist
im Compose-Stack standardmässig freigegeben. Der Shellstart bleibt ohne
zusätzliche S3-Freigabe Vorschau.

### Jenkins lokal starten

```bash
cd ../dateninfrastruktur-jenkins-dev
./bin/start.sh
```

`start.sh` baut oder aktualisiert zuerst das Offline-Bundle, installiert die
Jenkins-Plugins und startet danach Jenkins mit Java 21. Fuer GRETL und Gradle
exportiert das Skript separat Java 17.

Das vorhandene Home wird dabei wiederverwendet. Fuer einen isolierten Neustart
mit leerer Konfiguration:

```bash
cd ../dateninfrastruktur-jenkins-dev
./bin/start-fresh.sh
```

Das Skript setzt eine zuvor gebaute Plugin-HPI unter
`../dateninfrastruktur-jenkins-gretl-plugin/target/` voraus und legt sie automatisch im
frischen Home ab. Ein abweichender Build kann mit
`PLUGIN_HPI_SOURCE=/pfad/zur/plugin.hpi` angegeben werden.

`start-fresh.sh` leert ausschliesslich ein Home unter `build/`. Ein getracktes
Quell-`jenkins-home/` gibt es im Zielrepo nicht; das Laufzeit-Home entsteht neu. Ein anderes bestehendes Home kann mit
`JENKINS_HOME_DIR=/pfad/zum/home ./bin/start.sh` verwendet werden.

### Plugin aus dem Schwester-Repo installieren

```bash
cd ../dateninfrastruktur-jenkins-gretl-plugin
export JAVA_HOME="${JAVA21_HOME:-$HOME/.sdkman/candidates/java/current}"
export PATH="$JAVA_HOME/bin:$PATH"
mvn -ntp package

cd ../dateninfrastruktur-jenkins-dev
./bin/install-gretl-datenportal-plugin.sh
```

Wenn Jenkins bereits laeuft, ist anschliessend ein voller Restart noetig.

### Seed-Job

Nach dem Jenkins-Start legt das Plugin den Job `gretl-datenportal-seed`
automatisch an. Der Job:

- ist aktiviert, sobald `THEMEN_REPO_URL` oder ein Pfad konfiguriert ist;
- laeuft per Cron `H/15 * * * *`;
- kann fuer sofortige lokale Tests manuell gestartet werden.

Der Seed-Job wird nicht mehr per JCasC/Job-DSL erzeugt. Fuer bestehende lokale
Jenkins-Homes kann der alte Job `gretl-datenportal-plugin-generator-local`
manuell geloescht werden; relevant ist neu ausschliesslich
`gretl-datenportal-seed`.

Die lokale JCasC-Konfiguration verwendet die projektbezogene Matrix-
Autorisierung aus `matrix-auth`. Die Testkonten sind:

| Benutzer | Passwort | Zweck |
|---|---|---|
| `admin` | `admin` | Jenkins-Administrator und Bootstrap |
| `seed-user` | `seed` | Mitglied des konfigurierten Seeder-Teams |
| `read-user` | `read` | Nur Lesezugriff auf Organisationen |
| `agi-user` | `agi` | Lesen und Bauen des AGI-Jobs |
| `mfk-user` | `mfk` | Lesen und Bauen des MFK-Jobs |
| `statistikdienst-user` | `statistikdienst` | Lesen und Bauen des Statistikdienst-Jobs |

Für lokale Tests ist keine AD-/LDAP-Umgebung nötig: JCasC verwendet den lokalen
Security-Realm und legt diese Konten beim Start an. Normale Benutzer erhalten
global nur `Overall/Read`. `Item/Read` und
`Item/Build` kommen ausschliesslich aus den ACLs der vom Plugin verwalteten
Jobs. Das lokale Seeder-Team wird über
`seedJobOperatorsTeam: gretl-datenportal-seed-operators` referenziert und in
`shared/gretl-datenportal-teams.yaml` des Themenrepos definiert. Der erste
Seed-Lauf wird mit `admin` ausgeführt; danach wird auch die ACL des Seeder-Jobs
aus der Teams-Datei synchronisiert. Die Teammitglieder werden über ihre
Jenkins-Benutzer-IDs aufgelöst; in einer produktiven Umgebung müssen diese IDs
zur konfigurierten AD-/LDAP-/Entra-Authentisierungsquelle passen.

Die zentrale [Konfigurationsreferenz](docs/biblios/entwicklung/referenz-konfiguration.adoc)
vergleicht Shellstart, Dev-Compose und Produktion. Sie enthält ENV-Defaults,
Pflichtwerte, Git-Schreibfreigabe und die nötigen Schritte nach Änderungen.

Der Seed-Lauf kennt zwei Modi. `managed-git` ist der Default von `bin/start.sh`:
Jenkins aktualisiert seinen internen Checkout mit dem committed Stand des
konfigurierten Branches. `working-tree` ist nur für lokale Entwicklung gedacht:
Beim Seed-Lauf wird der externe Arbeitsbaum inklusive uncommitteter und
untracked Änderungen in einen Jenkins-internen Snapshot kopiert. Das externe
Themenrepo wird dabei nicht verändert; der Snapshot bleibt bis zum nächsten
Seed-Lauf unverändert. Der Dev-Stack verwendet diesen Snapshot-Modus bereits
fest. Für einen lokalen Shellstart mit diesem Modus:

```bash
THEMEN_REPO_MODE=working-tree ./bin/start.sh
```

Im produktionsnahen Modus müssen Änderungen committen und auf dem konfigurierten
Branch bereitgestellt werden. Danach den Seed-Job zuerst als `admin / admin`
starten und die ACLs mit
`seed-user / seed`, `read-user / read`, `agi-user / agi`, `mfk-user / mfk`
und `statistikdienst-user / statistikdienst` prüfen. Die
vollständige Anleitung steht in
`docs/biblios/entwicklung/lokaler-jenkins-start.adoc`.

### Offline-Bundle separat bauen

```bash
cd ../dateninfrastruktur-jenkins-dev
./bin/build-offline-bundle.sh
```

Das Bundle landet standardmaessig unter `build/offline-bundle/`.

### Docker-Image bauen

```bash
cd ../dateninfrastruktur-jenkins-dev
./bin/build-image.sh
```

Der lokale Build benötigt Docker mit Buildx und Python 3. Optional legt
`IMAGE_PLATFORM=linux/arm64` beziehungsweise `linux/amd64` genau eine Plattform
fest; ohne Angabe gilt die Standardplattform des Builders. Das Image wird mit
`--load` lokal geladen und vor Erfolgsmeldung offline geprüft. Ein Multiarch-Image
wird im Veröffentlichungsworkflow aus den einzeln geprüften Images gebildet.

`bin/prepare-image-context.sh` bereitet unter `build/docker-context` Dockerfile,
Plugin, Offline-Bundle und `build-args.json` vor. Ein bereits vorbereiteter
Kontext kann ohne erneute Maven-/Gradle-Auflösung gebaut werden:

```bash
IMAGE_PLATFORM=linux/arm64 ./bin/build-image.sh --prepared-context build/docker-context
```

Build-Versionen und Labels kommen bei dieser Variante ausschliesslich aus dem
vorbereiteten Kontext. `IMAGE_NAME` wählt weiterhin den lokalen Zielnamen.
`THEMEN_REPO_DIR` muss auf den dazugehörigen Themenrepo-Stand für die Tests zeigen.

Das gemeinsame Image heisst `dateninfrastruktur-jenkins`. Der lokale Default-Tag ist
`dateninfrastruktur-jenkins:local`; für die Registry kann `IMAGE_NAME` und
`IMAGE_VERSION` gesetzt werden. Es unterstützt die Laufzeitmodi
`JENKINS_RUNTIME_MODE=dev` und `JENKINS_RUNTIME_MODE=production`. Im
Produktionsmodus prüft der Entrypoint die AD- und Deployment-Variablen; im
Dev-Modus muss die lokale JCasC von aussen gemountet und über
`CASC_JENKINS_CONFIG` ausgewählt werden. Die Modusvariable selbst wählt keine
JCasC-Datei aus. Die mitgelieferte Produktions-JCasC setzt den Repository-Modus
fest auf `managed-git`. Git-Rückschreiben bleibt in beiden Laufzeiten
standardmässig deaktiviert; auch `managed-git` aktiviert es nicht automatisch.

Das Image enthält den Jenkins-Controller, Java 17 für GRETL, das vorbereitete
Offline-Bundle und das beim Image-Bau installierte Datenportal-Plugin. Das
Themenrepo wird nicht in das Image kopiert, sondern zur Laufzeit über
`THEMEN_REPO_URL`/`THEMEN_REPO_PATH` und `THEMEN_REPO_BRANCH` gesetzt. Für das
Bauen des Offline-Bundles dient `THEMEN_REPO_DIR` weiterhin als lokale
Build-Quelle.

Das Image verwendet `Europe/Zurich` als Systemzeitzone. Damit verwenden Jenkins,
Gradle und Konsolenlogs automatisch CET beziehungsweise CEST.

Das Image installiert die DuckDB-Extensions `postgres`, `spatial`, `excel`, `httpfs`
und `s3`
beim Build mit dem JDBC-Treiber aus dem Offline-Bundle. Sie liegen unter
`/opt/datenportal/duckdb-extensions`, ausserhalb des Jenkins-Homes, und sind
zur Laufzeit nur lesbar. `DUCKDB_EXTENSION_DIRECTORY` macht diesen Pfad fuer
GRETL verfuegbar; Jobs verwenden weiterhin `installExtensions false`.

`build-image.sh` prueft das gebaute Image automatisch ohne Netzwerk: Alle fuenf
Extensions werden geladen, und ein echter GRETL-Task exportiert CSV nach XLSX
und Parquet. Die Exporte werden anschliessend inhaltlich geprueft. Der Test
kann separat wiederholt werden:

```bash
./bin/test-image-duckdb.sh dateninfrastruktur-jenkins:local
```

Der Test verwendet `THEMEN_REPO_DIR` (Default `../dateninfrastruktur-themenrepo`)
fuer Wrapper und Gradle-Initialisierung. Er benoetigt Docker, aber kein
bestehendes Jenkins-Home. Die technischen Fixtures unter `tests/duckdb` dienen
ausschliesslich der Laufzeitpruefung; sie definieren keinen Publikationsjob.
Der lokale Shellstart installiert die Extensions ebenfalls für seine Plattform.

Der normale neue Buildpfad ist `PLUGIN_SOURCE=local`: Er baut den Checkout
unter `PLUGIN_REPO` und installiert dessen HPI. Ein fehlendes lokales
Plugin-Repo bricht den Build verständlich ab. `PLUGIN_SOURCE=maven` und
`PLUGIN_SOURCE=auto` bleiben nur als ausdrückliche Kompatibilitätsoptionen
bestehen; der Stack und der Veröffentlichungsworkflow verwenden `local`.

Das HPI wird ausschliesslich beim Image-Bau installiert. GRETL `5.0.0-SNAPSHOT`
und die übrigen Gradle-/GRETL-Artefakte werden beim Offline-Bundle-Bau aus den
im Themenrepo definierten Repositories geladen und zur Laufzeit offline
verwendet.

## Langform-Doku

Die technische Langform-Doku liegt unter
[docs/biblios/entwicklung/index.adoc](docs/biblios/entwicklung/index.adoc).

## Schwester-Repositories

- [dateninfrastruktur-themenrepo](https://github.com/sogis/dateninfrastruktur-themenrepo)
  ist die kanonische Doku fuer Organisationsstruktur, Datensaetze,
  `gretl-datenportal-job.yaml`, `shared/gretl-datenportal-teams.yaml`,
  `shared/Jenkinsfile` und den Gradle-Build-Vertrag.
- [dateninfrastruktur-jenkins-gretl-plugin](https://github.com/sogis/dateninfrastruktur-jenkins-gretl-plugin)
  ist die kanonische Doku fuer Scanner, Startformular, Rechtepruefung,
  Seed-Builder und generierte Jenkins-Jobs.

### SQL-Lieferverarbeitung offline prüfen

```bash
python3 -m venv build/publication-test-venv
. build/publication-test-venv/bin/activate
pip install -r tests/publication/requirements.txt
./bin/test-image-publication.sh dateninfrastruktur-jenkins:local
# Alternativ nach dem Image-Bau automatisch ausführen:
RUN_PUBLICATION_TESTS=1 ./bin/build-image.sh
```

Die Prüfung verwendet den Arbeitsstand des Themenrepos, einen extern
bereitzustellenden kompatiblen Fixture-Checkout (`PILOT_REPO_DIR`), eine
temporäre Kopie und ein separates lokales Bare-Repository. Alle GRETL-Prozesse
laufen ohne Netzwerk.
Details zu Modellen, Extensions und Ergebnissen stehen in der
[Offline-Bundle-Dokumentation](docs/biblios/entwicklung/offline-bundle.adoc).

### S3-Gesamtstand

Der Standardjob erzeugt zusätzlich `opendata.rdf` und veröffentlicht die Datei
nach bestätigter XTF-Annahme. RDF-Fehler bleiben im Bericht getrennt und
verhindern den nachfolgenden Reload. Der Standardjob liest `current.json` und die bezeichneten Gesamt-XTF über HTTP.
`s3Publish=true` gibt die Publikation frei; Git benötigt zusätzlich seine bisherige
Freigabe und schreibt nur das ausgewählte Datenblatt. Im Formular kann ohne Upload
ein Repository-Datenblatt abgeglichen und optional das Portal neu geladen werden.
Defaults und erforderliche ENV-Werte stehen in der
[Konfigurationsreferenz](docs/biblios/entwicklung/referenz-konfiguration.adoc).

Der Offline-Test führt keine Git-Schreiboperationen aus. Die lokale
S3-Publikation und der Wiederanlauf werden im Dev-Stack über
`./scripts/verify-foundation.sh` und `./scripts/test-restart.sh` geprüft.

## Multiarch-Veröffentlichung über GitHub Actions

Der Workflow `.github/workflows/publish-docker-image.yml` liegt im GitHub-Repo
`sogis/dateninfrastruktur-jenkins-dev` und ist die aktive Quelle. Es gibt keinen
Codeberg-Mirror und keine Tag-Strategie: Jeder Push auf `main` sowie ein
manueller Start veröffentlichen ein neues Image.

Docker Hub und GHCR erhalten jeweils den Lauf-Tag `0.1.<run-number>` und
`latest` für **linux/amd64 und linux/arm64**. Voraussetzungen im
GitHub-Repository sind die Secrets `DOCKER_USERNAME` und `DOCKER_PASSWORD`
sowie `GITHUB_TOKEN` mit `packages: write` für GHCR.

1. `prepare` baut das Plugin aus dem lokalen Schwester-Repo und erstellt ein
   gemeinsames Kontext-Artefakt mit Offline-Bundle, Modellen und demselben
   Themenrepo-Commit für beide Architekturen. Java 21 baut das Plugin, Java 17
   wird für GRETL/Gradle bereitgestellt.
2. `build` verwendet native Runner `ubuntu-24.04` und `ubuntu-24.04-arm` mit
   Buildx. Beide bauen mit identischem Kontext, prüfen die Imagearchitektur
   und führen die DuckDB-Offline-Tests aus.
3. Erfolgreiche Jobs pushen nur Zwischen-Tags
   `ci-<run-id>-<run-attempt>-<arch>` in beide Registries.
4. `publish` läuft nur nach Erfolg beider Architekturjobs. Es prüft zuerst
   sämtliche Zwischenimages auf Plattform und Digest, erstellt die gemeinsamen
   Manifeste aus diesen Digests und prüft danach den Versions-Tag und `latest`
   in beiden Registries. Bei fehlgeschlagenem Build/Test bleiben beide Tags
   unverändert.

Für einen erneuten Versuch **alle Jobs erneut ausführen**, damit beide
Architekturimages zum gleichen `run-attempt` gehören. Zwischen-Tags können bei
Fehlern zurückbleiben; sie sind keine freigegebenen Versionen. Updates über zwei
Registries sind nicht atomar: Scheitert der abschliessende Registryzugriff, den
Workflowstatus und beide Registry-Manifeste prüfen und den ganzen Lauf wiederholen.
Automatisches Löschen fremder oder älterer Images findet nicht statt.

Lokale Regressionstests (ohne Push):

```bash
python3 -m unittest discover -s tests
```

Sie prüfen unter anderem den Abbruch bei falscher Plattform, das Weiterreichen
von Testfehlern und die Veröffentlichungssperre bei fehlenden Architekturimages.
Der Workflow baut keine Sodata-Images und führt keine S3-Publikation aus.

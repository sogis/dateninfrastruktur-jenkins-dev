# AGENTS.md – dateninfrastruktur-jenkins-dev

## Vor Beginn lesen

Lies ausdrücklich `../AGENTS.md` und `../dateninfrastruktur-dev-stack/docs/implementation/grundinstallation/AUFTRAG_GRUNDINSTALLATION.md` sowie den zur aktuellen Rolle gehörenden Startprompt im selben Dokumentationsordner. Fehlt `../AGENTS.md`, lies ersatzweise `../dateninfrastruktur-dev-stack/docs/implementation/grundinstallation/templates/AGENTS.workspace.md`. Verlasse dich nicht auf automatische Vererbung über Git-Grenzen. Weitere betroffene Schwesterrepos haben eigene AGENTS-Dateien.

Diese Regeln gelten für Implementierung **und** Review. Ein Reviewauftrag erlaubt keine Änderungen an Produktdateien, Tests, Anforderungen oder AGENTS-Dateien; Befunde melden, nicht selbst reparieren. Builds/Tests nur mit eigenen Laufzeitdaten. Quellrepos, fremde Änderungen und laufende fremde Instanzen erhalten; keine Secrets in Git oder Berichten.

## Verantwortung

Dieses Repo baut die Jenkins-/GRETL-Laufzeit und installiert das eigene Plugin. Es ist kein zweites Jenkins-Plugin.

## Besondere Regeln

- Kein getracktes Quell-`jenkins-home/`, keine Quell-Secrets und keine alte Laufzeit-Historie übernehmen. Frisches eigenes Jenkins-Volume verwenden.
- `PLUGIN_SOURCE=local`; Pluginquelle ausschliesslich `../dateninfrastruktur-jenkins-gretl-plugin`. Fehlende Quelle oder Buildfehler sind Fehler, kein Anlass zum alten HPI-Download.
- Bestehende gepinnte `plugins.txt` vollständig übernehmen; keine parallele Pluginbereinigung.
- Jenkins im lokalen `dev`-Modus mit dem eigenen Stack-JCasC starten. Keine aktive AD-Anmeldung, keine externen E-Mails, kein Git-Writeback.
- Java 21 für Jenkins/Plugin und die vorhandene Java-17-GRETL-Laufzeit sowie Offline-/Modellbundle erhalten. Versionen und Wrapper am konkreten Quellstand prüfen.
- Bundle-/Themenrepo-Pfade auf `../dateninfrastruktur-themenrepo` richten. Bei Worktrees `.git`-Dateien korrekt als Git-Arbeitskopie erkennen.
- Interne Plugin-ID, Bundlepfade und JCasC-Verträge gemäss Auftrag unverändert lassen, sofern keine begründete minimale Laufzeitkorrektur nötig ist.

## Nachweise

Frisch gebautes Plugin und tatsächlich installiertes Artefakt per SHA256 vergleichen. Erfolgreichen JCasC-Start, aktives Plugin, Seedjob und benötigte GRETL-/INTERLIS-Dateien im Integrationsstack prüfen. Abhängigkeiten und Snapshot-JAR-Hashes erfassen; Geheimnisse nicht protokollieren.

## Geltung der historischen Aufträge

Die vorstehenden MA-0–F-/Grundinstallationsgrenzen gelten nur für ihre damaligen
Aufträge. Für den ausdrücklich aktivierten MA-G-Auftrag gilt `../AGENTS.md` und
vollständig `../dateninfrastruktur-dev-stack/docs/implementation/storage-and-delivery/`.
Aktive Altverträge werden gemäss MA-G ersetzt; Sicherheits- und Datenerhaltungsregeln
bleiben bindend. Historische Dokumente und Nutzerarbeit nicht umschreiben.

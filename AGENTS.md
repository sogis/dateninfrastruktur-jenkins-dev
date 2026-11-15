# dateninfrastruktur-jenkins-dev

Im gemeinsamen Dateninfrastruktur-Workspace vor repoübergreifender Arbeit
`../AGENTS.md` ausdrücklich lesen und die Repo-Grenzen verifizieren. Bei einem
Einzelclone gelten die lokalen Regeln und Bedienhinweise im README. Für
repoübergreifende Aufträge zuerst den verifizierten Workspace bereitstellen.

Dieses Repo baut das Jenkins-Laufzeitimage. Das HPI stammt aus dem
Schwestercheckout des Plugins. Das Image installiert die veröffentlichte GRETL-6-Distribution aus Maven
und den festen CSV-Job.
Der Buildweg steht im README. Testbuilds verwenden eigene Kontexte und
ein eigenes Jenkins-Home.

Im gemeinsamen Stack übernimmt OIDC die Anmeldung. Die Admin-API prüft
Fachrechte, der Jenkins-Job startet den festen GRETL-Job. Technische
Credentials, JCasC und installierte Pluginversionen konsistent halten.

Vor grösseren Änderungen `.agents/skills/simplify-change/SKILL.md` anwenden.
Vor PR-Abschluss unabhängig mit `.agents/skills/review-change/SKILL.md` prüfen.

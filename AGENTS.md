# dateninfrastruktur-jenkins-dev

Im gemeinsamen Dateninfrastruktur-Workspace vor repoübergreifender Arbeit
`../AGENTS.md` ausdrücklich lesen und die Repo-Grenzen verifizieren. Bei einem
Einzelclone gelten die lokalen Regeln und Bedienhinweise im README. Für
repoübergreifende Aufträge zuerst den verifizierten Workspace bereitstellen.

Dieses Repo baut das Jenkins-Laufzeitimage. Das HPI stammt aus dem
Schwestercheckout des Plugins. Das geprüfte GRETL-Offlinebundle und der
fixierte CSV-Runner werden mit ihren Versions- und Hashbindungen gebaut.
Der Buildweg steht im README. Testbuilds verwenden eigene Kontexte und
ein eigenes Jenkins-Home.

Im gemeinsamen Stack übernimmt OIDC die Anmeldung. Die Admin-API prüft
Fachrechte, der Jenkins-Job führt den gebundenen Plan aus. Technische
Credentials, JCasC und installierte Pluginversionen konsistent halten.

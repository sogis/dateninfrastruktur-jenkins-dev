#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
stack="$root/../dateninfrastruktur-dev-stack"
plugin="$root/../dateninfrastruktur-jenkins-gretl-plugin"
context="${1:?Explicit new build context directory required}"
(umask 077; mkdir "$context")

source "$root/bin/java-env.sh"
activate_java_home "$(resolve_java_home 21 JAVA21_HOME 'Java 21 for the Jenkins HPI')"
(cd "$plugin" && mvn -ntp clean package)
cp "$root"/{Dockerfile,plugins.txt,docker-entrypoint.sh,gretl-dist.gradle,oidc-plugin.sha256} "$context/"
cp -R "$root/jobs" "$context/"
cp "$stack/services/jenkins/jenkins-stack.yaml" "$context/jenkins.yaml"
cp "$plugin/target/jenkins-gretl-dateninfrastruktur-plugin.hpi" "$context/delivery.jpi"

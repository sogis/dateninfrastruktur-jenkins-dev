#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${IMAGE_NAME:?Explicit local Jenkins candidate image tag required}"
if [[ $# -ne 1 ]]; then
  printf 'Usage: IMAGE_NAME=<local tag> build-image.sh <new context>\n' >&2
  exit 2
fi
context="$1"
(umask 077; mkdir "$context")

source "$root/bin/java-env.sh"
activate_java_home "$(resolve_java_home 21 JAVA21_HOME 'Java 21 for the Jenkins HPI')"
plugin="$root/../dateninfrastruktur-jenkins-gretl-plugin"
(cd "$plugin" && mvn -ntp clean package)
cp "$root/../dateninfrastruktur-dev-stack/services/jenkins/jenkins-stack.yaml" "$context/jenkins.yaml"
cp "$plugin/target/jenkins-gretl-dateninfrastruktur-plugin.hpi" "$context/delivery.jpi"
args=(buildx build --load --no-cache-filter gretl_dist)
if [[ -n "${IMAGE_PLATFORM:-}" ]]; then args+=(--platform "$IMAGE_PLATFORM"); fi
exec docker "${args[@]}" --build-context "build-inputs=$context" \
  --build-arg "IMAGE_VERSION=${IMAGE_VERSION:-local}" -t "$IMAGE_NAME" "$root"

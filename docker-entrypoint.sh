#!/usr/bin/env bash
set -euo pipefail
: "${JENKINS_URL:?Explicit Compose Jenkins URL required}"
: "${DI_JENKINS_ISSUER:?Explicit Keycloak issuer required}"
for key in DI_JENKINS_OIDC_CLIENT_SECRET DI_INGESTION_PLUGIN_SECRET DI_INGESTION_EXECUTOR_CLIENT_SECRET JENKINS_ADMIN_PASSWORD DI_STORAGE_WRITER_ACCESS_KEY DI_STORAGE_WRITER_SECRET_KEY DI_CH_LOADER_PASSWORD; do
  [[ ! -v "$key" && -r "/run/secrets/$key" && -s "/run/secrets/$key" ]] || {
    printf 'Jenkins requires its explicit mounted credential: %s\n' "$key" >&2
    exit 1
  }
done
[[ ${DI_JENKINS_IMAGE_SHA256:-} =~ ^[0-9a-f]{64}$ ]] || { printf "Bind the explicit Jenkins candidate image to this Compose runtime.\n" >&2; exit 1; }
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"

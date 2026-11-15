#!/usr/bin/env bash
set -euo pipefail
: "${JENKINS_URL:?Explicit Compose Jenkins URL required}"
: "${DI_JENKINS_ISSUER:?Explicit Keycloak issuer required}"
for key in DI_JENKINS_OIDC_CLIENT_SECRET DI_GRETL_DELIVERY_CLIENT_SECRET JENKINS_ADMIN_PASSWORD DI_STORAGE_WRITER_ACCESS_KEY DI_STORAGE_WRITER_SECRET_KEY DI_CH_LOADER_PASSWORD; do
  [[ ! -v "$key" && -r "/run/secrets/$key" && -s "/run/secrets/$key" ]] || {
    printf 'Jenkins requires its explicit mounted credential: %s\n' "$key" >&2
    exit 1
  }
done
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"

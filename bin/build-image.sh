#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${IMAGE_NAME:?Explicit local Jenkins candidate image tag required}"
if [[ $# -eq 2 && "$1" == --prepared-context ]]; then
  context="$2"
elif [[ $# -eq 1 ]]; then
  context="$1"
  "$root/bin/prepare-image-context.sh" "$context"
else
  printf 'Usage: IMAGE_NAME=<local tag> build-image.sh [--prepared-context] <context>\n' >&2
  exit 2
fi
metadata="$(python3 - "$context/build-args.json" <<'PY'
import json,sys
args=json.load(open(sys.argv[1]));keys={'JENKINS_IMAGE','IMAGE_VERSION','PLUGIN_VERSION','GRETL_VERSION','THEMEN_REPO_REVISION','PLUGIN_REPO_REVISION','G0_TOOLCHAIN_IMAGE','PLUGIN_HPI_SHA256'}
if set(args)!=keys or any(not isinstance(v,str) or not v or '\n' in v or '\r' in v for v in args.values()):raise SystemExit('Invalid explicit build metadata')
for k,v in args.items():print(k+'='+v)
PY
)"
args=(buildx build --load --provenance=false)
if [[ -n "${IMAGE_PLATFORM:-}" ]]; then args+=(--platform "$IMAGE_PLATFORM"); fi
while IFS= read -r argument; do args+=(--build-arg "$argument"); done <<< "$metadata"
docker "${args[@]}" -f "$context/Dockerfile" -t "$IMAGE_NAME" "$context"

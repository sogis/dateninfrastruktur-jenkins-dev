#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${IMAGE_NAME:?Explicit local Jenkins candidate image tag required}"
if [[ $# -ne 1 ]]; then
  printf 'Usage: IMAGE_NAME=<local tag> build-image.sh <new context>\n' >&2
  exit 2
fi
context="$1"
"$root/bin/prepare-image-context.sh" "$context"
args=(buildx build --load --no-cache-filter gretl_dist)
if [[ -n "${IMAGE_PLATFORM:-}" ]]; then args+=(--platform "$IMAGE_PLATFORM"); fi
docker "${args[@]}" --build-arg "IMAGE_VERSION=${IMAGE_VERSION:-local}" -t "$IMAGE_NAME" "$context"

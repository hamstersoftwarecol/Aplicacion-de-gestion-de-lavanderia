#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LAUNDRY_BASE_HREF="${1:-/}"
if [[ ! "$LAUNDRY_BASE_HREF" =~ ^/[A-Za-z0-9/_-]*$ ]] || [[ "$LAUNDRY_BASE_HREF" != */ ]]; then
  echo 'La ruta base debe comenzar y terminar en / y contener solo letras, números, /, _ o -.' >&2
  exit 1
fi
LAUNDRY_PUBLIC_CONFIG="$(mktemp)"
trap 'rm -f "$LAUNDRY_PUBLIC_CONFIG"' EXIT
python3 scripts/deployment_config.py "$LAUNDRY_PUBLIC_CONFIG"
flutter pub get --enforce-lockfile
flutter build web --release --no-wasm-dry-run \
  --base-href "$LAUNDRY_BASE_HREF" \
  --dart-define-from-file="$LAUNDRY_PUBLIC_CONFIG"
# GitHub Pages must serve Flutter's underscore-prefixed generated assets as-is.
touch build/web/.nojekyll

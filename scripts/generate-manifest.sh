#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/client"
MANIFEST="$CLIENT_DIR/manifest.json"
VERSION="${1:-$(date -u +%Y%m%d%H%M%S)}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  printf '{\n'
  printf '  "version": "%s",\n' "$VERSION"
  printf '  "files": [\n'

  first=1
  while IFS= read -r -d '' file; do
    rel="${file#$ROOT_DIR/}"
    size="$(stat -c '%s' "$file")"
    sha="$(sha256sum "$file" | awk '{print $1}')"

    if [[ "$first" -eq 0 ]]; then
      printf ',\n'
    fi
    first=0

    printf '    { "path": "%s", "size": %s, "sha256": "%s" }' "$rel" "$size" "$sha"
  done < <(find "$CLIENT_DIR" -type f ! -path "$MANIFEST" -print0 | sort -z)

  printf '\n'
  printf '  ]\n'
  printf '}\n'
} > "$tmp"

mv "$tmp" "$MANIFEST"

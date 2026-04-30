#!/usr/bin/env bash
#
# import-snomed.sh - Upload an RF2 release zip to local Snowstorm and start an import.
#
# Usage:  ./scripts/import-snomed.sh <path-to-rf2.zip> [SNAPSHOT|FULL|DELTA] [branch]
# Example: ./scripts/import-snomed.sh snomed-data/SnomedCT_InternationalRF2_PRODUCTION.zip

set -euo pipefail

SNOWSTORM_URL="${SNOWSTORM_URL:-http://localhost:8080}"
RF2_FILE="${1:-}"
IMPORT_TYPE="${2:-SNAPSHOT}"
BRANCH="${3:-MAIN}"

if [[ -z "$RF2_FILE" ]]; then
  echo "Usage: $0 <path-to-rf2.zip> [SNAPSHOT|FULL|DELTA] [branch]" >&2
  exit 1
fi

if [[ ! -f "$RF2_FILE" ]]; then
  echo "Error: file not found: $RF2_FILE" >&2
  exit 1
fi

echo "==> Checking Snowstorm is reachable at $SNOWSTORM_URL ..."
if ! curl -sf "$SNOWSTORM_URL/version" > /dev/null; then
  echo "Error: Snowstorm not responding at $SNOWSTORM_URL/version" >&2
  echo "Is the stack up?  docker compose ps" >&2
  exit 1
fi
echo "    OK"

echo "==> Creating import job (type=$IMPORT_TYPE, branch=$BRANCH) ..."
LOCATION=$(curl -sS -i -X POST "$SNOWSTORM_URL/imports" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"$IMPORT_TYPE\",\"branchPath\":\"$BRANCH\",\"createCodeSystemVersion\":true}" \
  | tr -d '\r' | awk '/^[Ll]ocation:/ {print $2}')

if [[ -z "$LOCATION" ]]; then
  echo "Error: failed to create import job (no Location header returned)" >&2
  exit 1
fi

IMPORT_ID="${LOCATION##*/}"
echo "    import id: $IMPORT_ID"

echo "==> Uploading $RF2_FILE (this may take a few minutes) ..."
curl -sS -X POST "$SNOWSTORM_URL/imports/$IMPORT_ID/archive" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$RF2_FILE"
echo
echo "    upload accepted; import is now running on the server."

echo "==> Polling import status (Ctrl-C to detach; the import will continue) ..."
# Disable pipefail/errexit inside the loop: transient curl/grep failures (e.g. just
# after upload while the server is still spinning the job up) must not kill us.
set +e +o pipefail
while true; do
  RESP=$(curl -sf "$SNOWSTORM_URL/imports/$IMPORT_ID" 2>/dev/null)
  # Match "status" : "<value>" with optional whitespace around the colon
  # (Snowstorm pretty-prints JSON, so a tight regex misses the field).
  STATUS=$(printf '%s' "$RESP" | grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | awk -F'"' '{print $(NF-1)}')
  TS=$(date '+%H:%M:%S')
  echo "    [$TS] status: ${STATUS:-unknown}"

  case "$STATUS" in
    COMPLETED)
      echo "==> Import COMPLETED."
      exit 0
      ;;
    FAILED)
      echo "==> Import FAILED. Check Snowstorm logs:  docker compose logs snowstorm" >&2
      exit 1
      ;;
  esac

  sleep 30
done

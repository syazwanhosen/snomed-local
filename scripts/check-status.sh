#!/usr/bin/env bash
#
# check-status.sh - One-line health summary for the local Snowstorm stack.

set -uo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
SNOWSTORM_URL="${SNOWSTORM_URL:-http://localhost:8080}"
BROWSER_URL="${BROWSER_URL:-http://localhost:80}"

check() {
  local name="$1" url="$2" path="$3"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url$path" || echo "000")
  if [[ "$code" =~ ^2 ]] || [[ "$code" =~ ^3 ]]; then
    printf '  %-14s  %s  (HTTP %s)\n' "$name" "OK     " "$code"
  else
    printf '  %-14s  %s  (HTTP %s) - %s\n' "$name" "DOWN   " "$code" "$url$path"
  fi
}

echo "Snowstorm local stack status:"
check "Elasticsearch" "$ES_URL"        "/_cluster/health"
check "Snowstorm"     "$SNOWSTORM_URL" "/version"
check "Browser UI"    "$BROWSER_URL"   "/"
echo
echo "Containers:"
docker compose ps 2>/dev/null || echo "  (run from the project root for docker compose status)"

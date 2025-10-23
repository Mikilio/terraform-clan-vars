#!/bin/bash

set -euo pipefail

TYPE="$1"

if [[ "$TYPE" == "users" ]]; then
  LIST=$(clan secrets users list 2>/dev/null)
elif [[ "$TYPE" == "machines" ]]; then
  LIST=$(clan secrets machines list 2>/dev/null)
else
  echo '{"error": "Invalid type"}' >&2
  exit 1
fi

RESULT=$(echo "$LIST" | grep -v '^$' | tr '\n' ',' | sed 's/,$//' || echo '')
echo "{\"result\": \"$RESULT\"}"

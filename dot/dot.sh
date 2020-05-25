#!/usr/bin/env sh

set -eu
set -o pipefail

echo "strict digraph {"
psql --tuples-only --no-psqlrc -c "$1" \
    | jq -r -f ./dot/dot.jq
echo '}'

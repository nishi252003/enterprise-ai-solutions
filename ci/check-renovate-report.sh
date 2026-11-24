#!/usr/bin/env bash
set -euo pipefail

report_file=$1
: "${RENOVATE_REPOSITORIES:?RENOVATE_REPOSITORIES must be set}"

if ! jq -e -s --arg repositories "$RENOVATE_REPOSITORIES" '
  (map(select(has("report"))) | last) as $result |
  ($repositories | split(",")) as $expected |
  ($result.report.repositories // {}) as $actual |
  length > 0 and
  all(.[]; (.level // 0) < 40) and
  ($result != null) and
  all($expected[]; . as $repo |
    ($actual | has($repo)) and (($actual[$repo].packageFiles // {}) | length > 0))
' "$report_file" >/dev/null; then
  echo "Renovate reported a warning/error or did not extract dependencies for every requested repository. Inspect $report_file." >&2
  exit 1
fi

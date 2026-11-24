#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
report=$(mktemp)
trap 'rm -f -- "$report"' EXIT
export RENOVATE_REPOSITORIES="example/one,example/two"

jq -nc '{level:30,report:{repositories:{"example/one":{packageFiles:{helmv3:[{}]}},"example/two":{packageFiles:{regex:[{}]}}}}}' >"$report"
bash ci/check-renovate-report.sh "$report"

echo '{"level":40,"msg":"lookup failed"}' >>"$report"
if bash ci/check-renovate-report.sh "$report" >/dev/null 2>&1; then
  echo "Expected warning to fail the report check" >&2
  exit 1
fi

jq -nc '{level:30,report:{repositories:{"example/one":{packageFiles:{helmv3:[{}]}}}}}' >"$report"
if bash ci/check-renovate-report.sh "$report" >/dev/null 2>&1; then
  echo "Expected a missing repository to fail the report check" >&2
  exit 1
fi

jq -nc '{level:30,report:{repositories:{"example/one":{packageFiles:{helmv3:[{}]}},"example/two":{packageFiles:{}}}}}' >"$report"
if bash ci/check-renovate-report.sh "$report" >/dev/null 2>&1; then
  echo "Expected a repository with no extracted files to fail the report check" >&2
  exit 1
fi

echo "Renovate report checks passed"

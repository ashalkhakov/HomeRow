#!/bin/bash
# The smoke test CI runs: HomeRow starts, types and quits, in a fresh home.
set -euo pipefail
export HOME=$(mktemp -d)
HR_SMOKE_TEST=1 timeout 120 xvfb-run -a "$1"

#!/bin/bash
# The smoke test CI runs, in a fresh home; before signing and after (the
# hardened runtime loads only frameworks signed by the same team).
set -euo pipefail
export HOME=$(mktemp -d)
export CFFIXED_USER_HOME="$HOME"
HR_SMOKE_TEST=1 "$1/Contents/MacOS/HomeRow"

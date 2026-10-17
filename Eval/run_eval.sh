#!/usr/bin/env bash
# Measures per-field extraction accuracy on Eval/samples (or a folder you pass).
#   Eval/run_eval.sh                                   # on-device parser
#   Eval/run_eval.sh --endpoint https://.../extract    # your deployed proxy
#   Eval/run_eval.sh path/to/samples --json Eval/results/report.json --verbose
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES="$ROOT/Eval/samples"
if [ $# -gt 0 ] && [[ "$1" != --* ]]; then SAMPLES="$(cd "$1" && pwd)"; shift; fi
mkdir -p "$ROOT/Eval/results"
if command -v swift >/dev/null 2>&1; then
  swift run -c release --package-path "$ROOT/MedListCore" medlist-eval "$SAMPLES" "$@"
else
  docker run --rm -v "$ROOT:/src" -v "$SAMPLES:/samples:ro" "${SWIFT_IMAGE:-swift:6.1-noble}" \
    swift run -c release --scratch-path /tmp/build --package-path /src/MedListCore medlist-eval /samples "$@"
fi

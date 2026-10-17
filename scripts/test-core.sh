#!/usr/bin/env bash
# Runs the MedListCore unit tests. Uses a local Swift toolchain if present (macOS/Linux),
# otherwise the official Swift Docker image.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if command -v swift >/dev/null 2>&1; then
  cd "$ROOT/MedListCore" && swift test "$@"
else
  IMAGE="${SWIFT_IMAGE:-swift:6.1-noble}"
  docker run --rm -v "$ROOT:/src" -w /src/MedListCore "$IMAGE" \
    bash -c "swift test --scratch-path /tmp/build $*"
fi

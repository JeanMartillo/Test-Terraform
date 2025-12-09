#!/usr/bin/env bash
set -euo pipefail

# Run tests for each subproject in this repository, setting PYTHONPATH
# so that the local `api` package for each service is importable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
cd "$ROOT_DIR"

VEVN="$ROOT_DIR/.venv"
if [ -f "$VEVN/bin/activate" ]; then
  # shellcheck disable=SC1090
  . "$VEVN/bin/activate"
  echo "Activated virtualenv at $VEVN"
else
  echo "Warning: virtualenv not found at $VEVN — continuing without activating venv"
fi

PROJECTS=("front-end" "newsfeed" "quotes")
FAIL=0

for proj in "${PROJECTS[@]}"; do
  if [ ! -d "$ROOT_DIR/$proj" ]; then
    echo "Skipping $proj: directory not found"
    continue
  fi

  echo "\n=== Running tests for $proj ==="
  if (cd "$ROOT_DIR/$proj" && PYTHONPATH="$ROOT_DIR/$proj" pytest -q); then
    echo "Tests passed for $proj"
  else
    echo "Tests failed for $proj"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo "\nOne or more test suites failed"
  exit 1
fi

echo "\nAll test suites passed"
exit 0

#!/usr/bin/env bash
#
# lint.sh - Run shellcheck on all shell scripts
#
# Usage: ./scripts/lint.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
  echo "Error: shellcheck is not installed" >&2
  echo "Install it with:" >&2
  echo "  Ubuntu/Debian: sudo apt install shellcheck" >&2
  echo "  macOS: brew install shellcheck" >&2
  exit 1
fi

echo "Running shellcheck on all shell scripts..."
echo ""

ERRORS=0

# Find all shell scripts
while IFS= read -r -d '' file; do
  echo "Checking $file"
  # Use -x flag to follow source directives
  # Exclude info-level warnings (SC1091, SC2012) for dynamic source paths and ls usage
  if ! shellcheck -x -e SC1091,SC2012 "$file"; then
    ((ERRORS++))
  fi
done < <(find . -type f -name "*.sh" -not -path "./.git/*" -print0)

echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo "✓ All shell scripts passed shellcheck!"
  exit 0
else
  echo "✗ Found $ERRORS file(s) with shellcheck warnings/errors"
  exit 1
fi

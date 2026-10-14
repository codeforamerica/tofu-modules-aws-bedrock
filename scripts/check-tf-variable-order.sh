#!/usr/bin/env bash
# Check that variable blocks in OpenTofu/Terraform files are in alphabetical order.

set -euo pipefail

failed=0

for file in "$@"; do
  vars=$(grep -E '^variable "' "$file" | sed 's/^variable "\([^"]*\)".*/\1/' || true)

  [ -z "$vars" ] && continue

  sorted=$(echo "$vars" | sort)

  if [ "$vars" != "$sorted" ]; then
    echo "ERROR: Variables in $file are not in alphabetical order."
    echo "  Current: $(echo "$vars" | tr '\n' ' ')"
    echo "  Expected: $(echo "$sorted" | tr '\n' ' ')"
    failed=1
  fi
done

exit $failed

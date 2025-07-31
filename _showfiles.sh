#!/bin/bash

# Get the absolute path of the current directory
BASE_DIR=$(pwd)

# Find all regular files excluding:
# - anything under .git
# - top-level files or directories starting with '_'
find . -type f \
  -not -path './.git/*' \
  | while read -r file; do
    # Strip leading './' for clean path comparison
    relpath="${file#./}"

    # Check top-level component (first folder or file)
    toplevel=$(echo "$relpath" | cut -d/ -f1)

    if [[ "$toplevel" == _* ]]; then
        continue  # skip top-level entries starting with _
    fi

    echo "===== File: $file ====="
    cat -- "$file"
    echo ""
done


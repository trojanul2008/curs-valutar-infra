#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
abs_root="$(cd "$ROOT" && pwd)"

is_excluded() {
  case "$1" in
    "$abs_root/.git/"*|"$abs_root/.git") return 0;;
    "$abs_root/README.md") return 0;;
    "$abs_root/LICENSE") return 0;;
    "$abs_root/bfg-1.14.0.jar") return 0;;
    "$abs_root/infrastructure/flux/flux-system/manifests/flux-controllers.yaml") return 0;;
    *) return 1;;
  esac
}

export LC_ALL=C
find "$ROOT" -type f -print0 \
| while IFS= read -r -d '' f; do
    fp="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
    if is_excluded "$fp"; then
      continue
    fi
    mime=$(file -b --mime-type "$f")
    case "$mime" in
      text/*|application/json|application/x-yaml|application/yaml|application/xml)
        echo "================================================================================"
        echo "FILE: $f"
        echo "--------------------------------------------------------------------------------"
        cat -- "$f"
        echo; echo
        ;;
      *)
        echo "================================================================================"
        echo "FILE: $f"
        echo "SKIPPED: binary or unsupported type ($mime)"
        echo
        ;;
    esac
done


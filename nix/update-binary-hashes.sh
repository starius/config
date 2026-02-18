#!/bin/bash
set -euo pipefail

trap 'echo "!!! Error occurred on line $LINENO. Aborting."; exit 1;' ERR

# Defaults
KEEP_RESULT_APPS=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    --keep)
      KEEP_RESULT_APPS=true
      ;;
    -h|--help)
      echo "Usage: $0 [--keep]"
      echo "  --keep   Do not remove the result-apps symlink at the end"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Try --help for usage" >&2
      exit 2
      ;;
  esac
done

nix build .#apps --out-link result-apps --max-jobs 1 --cores 1

echo "OK Flake build complete."

echo "- Computing hashes of binaries..."
nix-store --query --requisites ./result-apps | sort -k 1.45 > paths.txt
paste -d '\t' <(cat paths.txt) <(xargs nix-store --query --hash < paths.txt) > want-binary-hashes.txt

echo "OK Computed hashes of binaries."

rm paths.txt

# Remove the out-link unless user asked to keep it.
if [ "$KEEP_RESULT_APPS" = false ]; then
  rm result-apps
fi

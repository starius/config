#!/bin/bash
set -euo pipefail

trap 'echo "!!! Error occurred on line $LINENO. Aborting."; exit 1;' ERR

nix build .#apps --out-link result-apps

echo "OK Flake build complete."

echo "- Computing hashes of binaries..."
nix-store --query --requisites ./result-apps | sort -k 1.45 > paths.txt
paste -d '\t' <(cat paths.txt) <(xargs nix-store --query --hash < paths.txt) > want-binary-hashes.txt

echo "OK Computed hashes of binaries."

rm result-apps paths.txt

#!/usr/bin/env bash
set -euo pipefail

INPUT_DIR="data/credentials/mysecrets_unencrypted"
OUTPUT_DIR="deploy/mysecrets/templates"

mkdir -p "$OUTPUT_DIR"

for file in "$INPUT_DIR"/*.yaml; do
  filename=$(basename "$file")

  # Skip files containing "namespace" in the name
  if [[ "$filename" == *namespace* ]]; then
    echo "[!] Skipping $filename (contains 'namespace')"
    cat "$file" > "$OUTPUT_DIR/$filename"
    continue
  fi

  echo "[*] Sealing $filename..."
  cat "$file" | kubeseal --format=yaml > "$OUTPUT_DIR/$filename"
done

echo "[✓] Done sealing secrets."


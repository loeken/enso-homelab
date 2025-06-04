#!/bin/bash
set -euo pipefail

echo "🔍 Validating all provided environment variables..."

# Filter out known non-user env vars
ignore_prefixes=("GITHUB_" "RUNNER_" "CI" "HOME" "PATH" "PWD" "OLDPWD" "SHLVL")

missing=0

# Loop through all current env vars
while IFS='=' read -r key _; do
  # Skip ignored system vars
  for prefix in "${ignore_prefixes[@]}"; do
    if [[ "$key" == "$prefix"* ]]; then
      continue 2
    fi
  done

  if [ -z "${!key}" ]; then
    echo "❌ $key is not set!"
    missing=1
  fi
done < <(env)

if [ "$missing" -eq 1 ]; then
  echo "🚫 One or more required env vars are missing."
  exit 1
fi

echo "✅ All required env vars are present."

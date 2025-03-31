#!/bin/bash

REQUIRED_SECRETS=(
  "SSH_USERNAME"
  "SSH_SERVER_ADDRESS"
  "SSH_INTERNAL_ADDRESS"
  "SSH_SERVER_PORT"
  "SSH_PRIVATE_KEY"
  "TF_TOKEN_app_terraform_io"
  "HOSTNAME"
)

MISSING=0
echo "🔍 Checking for required secrets..."

for secret in "${REQUIRED_SECRETS[@]}"; do
  if [ -z "${!secret}" ]; then
    echo "❌ Missing secret: $secret"
    echo "➡️  To set it: gh secret set $secret --body \"...\""
    MISSING=1
  fi
done

if [ "$MISSING" -eq 1 ]; then
  echo "🚫 One or more required secrets are missing."
  echo "Setting SKIP_WORKFLOW=true to prevent further steps..."
  echo "SKIP_WORKFLOW=true" >> "$GITHUB_ENV"
  exit 0
fi

echo "✅ All required secrets are set."

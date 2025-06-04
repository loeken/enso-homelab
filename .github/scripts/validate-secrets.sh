#!/bin/bash
set -e

required_secrets=(
  SSH_USERNAME
  SSH_SERVER_ADDRESS
  SSH_INTERNAL_ADDRESS
  SSH_SERVER_PORT
  SSH_PRIVATE_KEY
  TF_TOKEN_app_terraform_io
  HOSTNAME
  TF_CLOUD_ORGANIZATION
  PAT_GITHUB_TOKEN
  RENOVATE_TOKEN
  DEPLOYMENT_TYPE
)

echo "🔍 Validating required GitHub secrets..."

missing=0
for var in "${required_secrets[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ $var is not set"
    missing=1
  fi
done

if [ "$missing" -eq 1 ]; then
  echo "🚫 One or more required secrets are missing."
  exit 1
fi

echo "✅ All required secrets are present."
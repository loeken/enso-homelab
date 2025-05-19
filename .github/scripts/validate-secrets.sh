required_vars="DEPLOYMENT_TYPE SSH_USERNAME SSH_SERVER_ADDRESS SSH_INTERNAL_ADDRESS SSH_SERVER_PORT SSH_PRIVATE_KEY TF_TOKEN_app_terraform_io HOSTNAME TF_CLOUD_ORGANIZATION PAT_GITHUB_TOKEN RENOVATE_TOKEN"
found=0
for var in $required_vars; do
  if [ -z "$(eval echo \$$var)" ]; then
    echo "❌ Required secret/env var $var is not set!"
    found=1
  fi
done
if [ "$found" -eq 1 ]; then
  exit 1
fi

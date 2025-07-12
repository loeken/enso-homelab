# Authelia Integration Guide

This document describes how Authelia is integrated with various applications in the enso-homelab setup.

## Overview

Authelia provides authentication and authorization for applications through two main methods:

1. **OIDC/OAuth2 Integration**: For applications that support native OIDC (✅ **Fully Automated**)
2. **Forward Auth**: For applications that don't have native OIDC support

### 🔐 Automated OIDC Setup
Applications with native OIDC support are **fully automated**:
- ✅ **No manual configuration required**
- ✅ **Automatic environment variable injection**
- ✅ **Configuration file generation**
- ✅ **Secret management**
- ✅ **One-click enablement** via `useAuthelia: true`

### 🚀 Forward Auth Setup
Applications without native OIDC support use forward authentication:
- ✅ **Automatic nginx annotations**
- ✅ **API endpoint bypass rules**
- ✅ **One-click enablement** via `useAuthelia: true`

## OIDC Integrations

### Jellyfin (Automated OIDC)

Jellyfin (version 10.8+) supports OIDC authentication. The integration is **fully automated** when enabled:

**Authelia Configuration:**
- Client ID: `jellyfin`
- Authorization Policy: `one_factor`
- Redirect URI: `https://jellyfin.{domain}/sso/OID/redirect/authelia`
- Scopes: `openid`, `profile`, `email`, `groups`

**Access Control Rules:**
- Bypass authentication for OIDC endpoints: `/sso/OID/*`, `/Auth/*`, `/api/*`, `/web/*`
- Main application requires `one_factor` authentication for `users` group

**Automated Setup:**
1. Enable Authelia integration: `jellyfin.useAuthelia: true`
2. OIDC configuration is automatically applied via:
   - Environment variables for connection settings
   - Configuration file for plugin settings
   - Secret management for client credentials

**No manual configuration required!** The OIDC plugin will be automatically configured with the correct Authelia endpoints and client settings.

### Grafana (Automated OIDC)

**Authelia Configuration:**
- Client ID: `grafana`
- Authorization Policy: `two_factor`
- Redirect URI: `https://grafana.{domain}/login/generic_oauth`
- Scopes: `openid`, `profile`, `groups`, `email`

**Automated Setup:**
- OIDC configuration is fully automated via `grafana-oauth-config` secret
- No manual configuration required when `observability.useAuthelia: true`

### NextCloud (Automated OIDC)

**Authelia Configuration:**
- Client ID: `nextcloud`
- Authorization Policy: `two_factor`
- Redirect URI: `https://nextcloud.{domain}/apps/user_oidc/code`
- Requires PKCE: `true`

**Automated Setup:**
1. Enable integration: `nextcloud.useAuthelia: true`
2. OIDC configuration is automatically applied via:
   - Configuration files for OIDC plugin settings
   - Secret replacement for client credentials
   - Automatic redirect and scope configuration

**No manual configuration required!** The user_oidc app will be automatically configured.

### Heimdallr (Automated OIDC)

**Authelia Configuration:**
- Client ID: `heimdallr`
- Authorization Policy: `two_factor`
- Redirect URI: `https://heimdallr.{domain}/auth/callback`

**Automated Setup:**
- OIDC configuration is fully automated via environment variables
- No manual configuration required when `heimdallr.useAuthelia: true`

## Forward Auth Integrations

Applications that don't support OIDC use nginx forward auth with Authelia:

### Jellyseerr

**Configuration:**
- Forward auth URL: `http://authelia.authelia.svc.cluster.local/api/authz/auth-request`
- Sign-in URL: `https://auth.{domain}`
- Bypass rules for API endpoints: `/api/*`, `/auth/*`, `/webhook/*`

### Media Management Applications

The following applications use forward auth:
- **Prowlarr**: Indexer management
- **Sonarr**: TV series management  
- **Radarr**: Movie management
- **NZBGet**: Download client

All are configured with:
- Authorization Policy: `two_factor` for `admins` group
- API endpoints bypassed for automation

### Other Applications

- **Vaultwarden**: Password manager with forward auth
- **Home Assistant**: Selective bypass for API and static resources
- **Wazuh**: Security monitoring (admin only)
- **Uptime Kuma**: Status monitoring with API bypass for metrics collection
- **Dashy**: Dashboard application (already configured)

## Required Secrets

The following secrets must be configured for automated OIDC integrations:

### Authelia Secret (`authelia` namespace)
```yaml
# OIDC client secrets (automatically used by Authelia)
oidc.sharedsecret.jellyfin: "<secure-random-string>"
oidc.sharedsecret.grafana: "<secure-random-string>"
oidc.sharedsecret.nextcloud: "<secure-random-string>"
oidc.sharedsecret.heimdallr: "<secure-random-string>"

# OIDC signing keys
identity_providers.oidc.jwks: "<rsa-key-pair-json>"
identity_providers.oidc.issuer_private_key: "<rsa-private-key>"

# Encryption keys
session.encryption.key: "<base64-encoded-key>"
storage.encryption.key: "<base64-encoded-key>"

# SMTP configuration
notifier.smtp.password: "<smtp-password>"
```

### Application-Specific Secrets

**Jellyfin OIDC Secret** (`media` namespace):
```yaml
# Used by Jellyfin for OIDC client authentication
JELLYFIN_OIDC_CLIENT_SECRET: "<secure-random-string>"
```

**NextCloud Secret** (`nextcloud` namespace):
```yaml
# Already includes OIDC client secret
oidc_client_secret: "<secure-random-string>"
```

**Heimdallr Secret** (`heimdallr` namespace):
```yaml
# Already includes OIDC client secret
OIDC_CLIENT_SECRET: "<secure-random-string>"
```

**Grafana OAuth Secret** (`observability` namespace):
```yaml
# Automatically applied via envFromSecret
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: "<secure-random-string>"
# (see full secret template in examples)
```

**Important:** Client secrets in application secrets must match the corresponding `oidc.sharedsecret.*` values in the Authelia secret.

## Enabling Integrations

To enable Authelia integration for any application, set the `useAuthelia` flag to `true` in the values file:

### OIDC Integrations (Fully Automated)
```yaml
jellyfin:
  enabled: true
  useAuthelia: true  # ✅ Enables automated OIDC integration

observability:
  enabled: true
  useAuthelia: true  # ✅ Enables automated OIDC for Grafana

nextcloud:
  enabled: true
  useAuthelia: true  # ✅ Enables automated OIDC integration

heimdallr:
  enabled: true
  useAuthelia: true  # ✅ Enables automated OIDC integration
```

### Forward Auth Integrations
```yaml
jellyseerr:
  enabled: true
  useAuthelia: true  # Enable forward auth with API bypass

uptimekuma:
  enabled: true  
  useAuthelia: true  # Enable forward auth with API bypass
```

**No manual configuration needed!** When `useAuthelia: true` is set:
- OIDC applications automatically configure their authentication settings
- Environment variables, configuration files, and secrets are managed automatically
- Applications will redirect to Authelia for authentication
- Users can log in with their Authelia credentials

## Access Control Policies

Authelia uses a hierarchical access control system:

1. **bypass**: No authentication required (for APIs, static content)
2. **one_factor**: Username/password authentication
3. **two_factor**: Username/password + TOTP/WebAuthn

**Group-based Access:**
- `users`: General users with access to media applications
- `admins`: Administrative users with access to management tools

## Troubleshooting

### Common Issues

1. **OIDC Discovery Failed**: Ensure Authelia is accessible at `https://auth.{domain}/.well-known/openid_configuration`

2. **Invalid Client Secret**: Verify the secret matches between Authelia config and application config

3. **Redirect URI Mismatch**: Ensure the redirect URI in Authelia matches exactly what the application sends

4. **Forward Auth 401**: Check that the auth-url annotation points to the correct Authelia service

### Useful Commands

```bash
# Test Authelia OIDC discovery
curl https://auth.example.com/.well-known/openid_configuration

# Check Authelia logs
kubectl logs -n authelia deployment/authelia

# Verify forward auth endpoint
curl -I http://authelia.authelia.svc.cluster.local/api/authz/auth-request
```

## Security Considerations

1. **Use strong random secrets** for all OIDC client secrets
2. **Enable 2FA** for administrative applications
3. **Regularly rotate** encryption keys and client secrets
4. **Monitor access logs** for suspicious activity
5. **Keep bypass rules minimal** - only include necessary API endpoints
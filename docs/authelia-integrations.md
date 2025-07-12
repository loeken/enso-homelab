# Authelia Integration Guide

This document describes how Authelia is integrated with various applications in the enso-homelab setup.

## Overview

Authelia provides authentication and authorization for applications through two main methods:

1. **OIDC/OAuth2 Integration**: For applications that support native OIDC
2. **Forward Auth**: For applications that don't have native OIDC support

## OIDC Integrations

### Jellyfin

Jellyfin (version 10.8+) supports OIDC authentication. The integration is configured as follows:

**Authelia Configuration:**
- Client ID: `jellyfin`
- Authorization Policy: `one_factor`
- Redirect URI: `https://jellyfin.{domain}/sso/OID/redirect/authelia`
- Scopes: `openid`, `profile`, `email`, `groups`

**Access Control Rules:**
- Bypass authentication for OIDC endpoints: `/sso/OID/*`, `/Auth/*`, `/api/*`, `/web/*`
- Main application requires `one_factor` authentication for `users` group

**Setup in Jellyfin:**
1. Enable Authelia integration in values: `jellyfin.useAuthelia: true`
2. Configure OIDC in Jellyfin admin panel:
   - Provider: `https://auth.{domain}`
   - Client ID: `jellyfin`
   - Client Secret: From `authelia` secret (`oidc.sharedsecret.jellyfin`)

### Grafana

**Authelia Configuration:**
- Client ID: `grafana`
- Authorization Policy: `two_factor`
- Redirect URI: `https://grafana.{domain}/login/generic_oauth`
- Scopes: `openid`, `profile`, `groups`, `email`

### NextCloud

**Authelia Configuration:**
- Client ID: `nextcloud`
- Authorization Policy: `two_factor`
- Redirect URI: `https://nextcloud.{domain}/apps/user_oidc/code`
- Requires PKCE: `true`

### Heimdallr

**Authelia Configuration:**
- Client ID: `heimdallr`
- Authorization Policy: `two_factor`
- Redirect URI: `https://heimdallr.{domain}/auth/callback`

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

The following secrets must be configured in the `authelia` secret:

```yaml
# OIDC client secrets
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

## Enabling Integrations

To enable Authelia integration for any application, set the `useAuthelia` flag to `true` in the values file:

```yaml
jellyfin:
  enabled: true
  useAuthelia: true  # Enable Authelia integration

jellyseerr:
  enabled: true
  useAuthelia: true  # Enable forward auth

uptimekuma:
  enabled: true  
  useAuthelia: true  # Enable forward auth with API bypass
```

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
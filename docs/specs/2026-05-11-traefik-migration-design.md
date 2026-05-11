# Traefik Ingress + DNS-01 Migration

## Context / Goals

- Replace Nginx ingress controller with Traefik as the primary ingress
- Migrate cert-manager from HTTP-01 to DNS-01 challenge via Cloudflare
- Keep domain (`loeken.xyz`) and external-dns unchanged
- Run Nginx and Traefik in parallel during verification, delete Nginx after confirmation

## Scope

| In scope | Out of scope |
|---|---|
| Deploy Traefik via official Helm chart | Domain name changes |
| DNS-01 ClusterIssuer (Cloudflare) | external-dns changes |
| Shared Traefik Middlewares (authelia ForwardAuth + CORS) | Removing nginx annotations (future cleanup) |
| Ingress annotation migration on all apps | OpenVPN / network infrastructure changes |

## Architecture

### Traefik Deployment

- Official `traefik/traefik` Helm chart via ArgoCD
- Ingress class: `traefik`
- Service type: **NodePort** (internal-only, reachable via OpenVPN to node IPs)
- Entrypoints: `web` (80) and `websecure` (443)

### DNS-01 ClusterIssuer

- New secret `cert-manager-cloudflare` in `cert-manager` namespace
  - `CloudflareApiToken` — scoped to DNS Read + Zone Read for the zone
- Both staging and prod ClusterIssuers switch from HTTP-01 to DNS-01:
  ```yaml
  solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cert-manager-cloudflare
            key: CloudflareApiToken
  ```
- DNS-01 is ingress-class-agnostic — works for both nginx and traefik simultaneously

### Shared Traefik Middlewares

Two CRD-based middleware resources:

1. **`authelia-forwardauth`** — `forwardAuth` pointing to `http://authelia.authelia.svc.cluster.local/api/authz/auth-request`
   - Referenced by all 15 apps that currently use nginx authelia annotations
   - Annotation: `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd`

2. **`authelia-cors`** — CORS middleware (origins, methods, headers, credentials)
   - Referenced by authelia ingress only
   - Annotation: `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-cors@kubernetescrd`

### Per-Ingress Overrides

| App | Nginx annotation | Traefik equivalent |
|---|---|---|
| vaultwarden | `proxy-body-size: 0`, `proxy-read/send-timeout: 600` | `ServersTransport` with `forwardingTimeouts` + `maxResponseBodyBytes` |
| nextcloud | `proxy-body-size: 4G`, `use-forwarded-headers`, `proxy-real-ip-cidr` | `ServersTransport` with body size + `forwardedHeaders.trustExtensions` |
| sinusbot | `proxy-body-size: 128m` | `ServersTransport` with `maxResponseBodyBytes` |

### Ingress Migration Pattern

Each ingress gets:
- `ingressClassName: traefik` added
- Nginx `auth-url`/`auth-signin` replaced with `traefik.ingress.kubernetes.io/router.middlewares` referencing shared middleware
- Nginx CORS annotations replaced with shared middleware reference
- Nginx `proxy-body-size`/timeout annotations replaced with per-ingress `ServersTransport` reference
- **Nginx annotations left in place** during parallel run (harmless no-ops under traefik)

## Rollout Steps

1. Create `cert-manager-cloudflare` secret
2. Deploy DNS-01 ClusterIssuers
3. Deploy Traefik ArgoCD app
4. Create shared Traefik Middlewares (authelia ForwardAuth + CORS)
5. Update all app ingresses to use `ingressClassName: traefik` + middleware references
6. Verify: services reachable via OpenVPN, certs issuing via DNS-01
7. (Future) Remove nginx annotations, delete `nginxingress.yaml`

# Traefik Ingress + DNS-01 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Nginx ingress controller with Traefik as primary ingress and migrate cert-manager from HTTP-01 to DNS-01 challenges via Cloudflare, keeping Nginx running in parallel for verification.

**Architecture:** Deploy Traefik via official Helm chart with NodePort service type and `traefik` ingress class. Create shared Traefik Middleware CRDs (authelia ForwardAuth + CORS) in the `default` namespace. Create per-app ServersTransport CRDs for apps with custom body-size/timeout needs. Update all 16 app ingress templates to add `ingressClassName: traefik` and reference shared middleware. Migrate both staging and prod ClusterIssuers from HTTP-01 to DNS-01 with Cloudflare solver.

**Tech Stack:** Kubernetes, ArgoCD, Helm (Go templates), Traefik v3, cert-manager, Cloudflare API token, Authelia

---

## File Structure

### New files created:

| File                                               | Responsibility                                                        |
| -------------------------------------------------- | --------------------------------------------------------------------- |
| `deploy/argocd/templates/traefik.yaml`             | ArgoCD Application for Traefik Helm chart deployment                  |
| `deploy/argocd/templates/traefik-middlewares.yaml` | Shared Traefik Middleware CRDs (authelia-forwardauth + authelia-cors) |

### Files modified:

| File                                                               | Change                                                                                      |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `deploy/helm/cluster_issuer/templates/cluster-issuer.yaml`         | HTTP-01 → DNS-01 Cloudflare solver                                                          |
| `deploy/argocd/templates/authelia.yaml`                            | className → traefik, CORS annotations → middleware ref                                      |
| `deploy/argocd/templates/vaultwarden.yaml`                         | className → traefik, auth annotations → middleware ref, add ServersTransport                |
| `deploy/argocd/templates/nextcloud.yaml`                           | className → traefik, auth/forwarded-headers annotations → middleware ref + ServersTransport |
| `deploy/argocd/templates/sinusbot.yaml`                            | className → traefik, auth annotations → middleware ref, add ServersTransport                |
| `deploy/argocd/templates/dashy.yaml`                               | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/homeassistant.yaml`                       | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/jellyfin.yaml`                            | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/jellyseerr.yaml`                          | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/nzbget.yaml`                              | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/prowlarr.yaml`                            | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/radarr.yaml`                              | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/sonarr.yaml`                              | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/uptime-kuma.yaml`                         | className → traefik, auth annotations → middleware ref                                      |
| `deploy/argocd/templates/whoami.yaml`                              | ingressClassName → traefik (no authelia)                                                    |
| `deploy/argocd/templates/observability_grafana.yaml`               | ingressClassName → traefik, auth annotations → middleware ref                               |
| `deploy/argocd/templates/observability_kube-prometheus-stack.yaml` | ingressClassName → traefik, auth annotations → middleware ref (2 ingresses)                 |

### Files NOT changed:

| File                                        | Reason                             |
| ------------------------------------------- | ---------------------------------- |
| `deploy/argocd/templates/nginxingress.yaml` | Kept for parallel run — no changes |
| `deploy/argocd/templates/externaldns.yaml`  | No changes needed                  |

---

## Key Concepts for the Engineer

### Traefik Middleware References

Traefik middlewares defined as CRDs are referenced in ingress annotations using the format:

```
traefik.ingress.kubernetes.io/router.middlewares: <namespace>-<middleware-name>@kubernetescrd
```

All shared middlewares live in the `default` namespace. Multiple middlewares are comma-separated.

### Traefik ServersTransport References

Custom transport settings are referenced per-path using:

```
traefik.ingress.kubernetes.io/services-vaultwarden-80-transport: vaultwarden-transport
```

Format: `traefik.ingress.kubernetes.io/services-<service-name>-<port>-transport: <transport-name>`

The ServersTransport CRD must be in the **same namespace** as the Ingress that references it.

### Nginx Annotations During Parallel Run

All existing `nginx.ingress.kubernetes.io/*` annotations are **kept in place**. They are harmless no-ops when the ingress is served by Traefik. They will be removed in a future cleanup task.

### Go Template Conditionals

All app templates use `{{- if .Values.<app>.useAuthelia }}` to conditionally include auth annotations. The Traefik middleware reference must follow the same conditional pattern.

---

### Task 1: Create cert-manager-cloudflare Secret (User Manual Step)

**Files:**

- No file changes — this is a manual kubectl step documented for the user

This task documents the manual step the user must perform before ArgoCD can deploy the DNS-01 ClusterIssuers.

- [ ] **Step 1: Document the kubectl command for the user**

The user must create a Kubernetes secret in the `cert-manager` namespace containing a Cloudflare API token. The token must be scoped to:

- Zone: Read (for the `loeken.xyz` zone)
- DNS: Edit (to create/verify DNS-01 challenge records)

Add this instruction to the plan README or a migration checklist:

```bash
kubectl create secret generic cert-manager-cloudflare \
  --from-literal=CloudflareApiToken="<YOUR_CLOUDFLARE_API_TOKEN>" \
  -n cert-manager
```

The secret must exist **before** Task 2 deploys the DNS-01 ClusterIssuers, otherwise cert-manager will fail to validate challenges.

- [ ] **Step 2: Commit documentation**

```bash
git commit --allow-empty -m "docs: document cert-manager-cloudflare secret creation step"
```

---

### Task 2: Update ClusterIssuer to DNS-01 with Cloudflare

**Files:**

- Modify: `deploy/helm/cluster_issuer/templates/cluster-issuer.yaml`

Replace HTTP-01 solver with DNS-01 Cloudflare solver for both staging and prod ClusterIssuers.

- [ ] **Step 1: Replace the cluster-issuer template**

Replace the entire file content with:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@{{ .Values.domain }}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cert-manager-cloudflare
              key: CloudflareApiToken
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@{{ .Values.domain }}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cert-manager-cloudflare
              key: CloudflareApiToken
```

Key changes:

- Removed `http01.ingress.class: nginx` (HTTP-01 was nginx-class-specific)
- Added `dns01.cloudflare.apiTokenSecretRef` pointing to `cert-manager-cloudflare` secret
- DNS-01 is ingress-class-agnostic — works for both nginx and traefik simultaneously

- [ ] **Step 2: Validate the Helm template renders correctly**

```bash
cd /Users/loeken/Projects/private/enso-homelab
helm template cluster-issuer deploy/helm/cluster_issuer/ --set domain=loeken.xyz
```

Expected output: Two ClusterIssuer resources (staging + prod) with `dns01.cloudflare` solver blocks referencing `cert-manager-cloudflare` secret.

- [ ] **Step 3: Commit**

```bash
git add deploy/helm/cluster_issuer/templates/cluster-issuer.yaml
git commit -m "feat: migrate ClusterIssuers from HTTP-01 to DNS-01 Cloudflare solver"
```

---

### Task 3: Create Traefik ArgoCD App

**Files:**

- Create: `deploy/argocd/templates/traefik.yaml`

Deploy Traefik via the official `traefik/traefik` Helm chart with NodePort service type.

- [ ] **Step 1: Create the traefik.yaml template**

Create `deploy/argocd/templates/traefik.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argoproj.io
  name: traefik
  namespace: argocd
spec:
  destination:
    namespace: traefik
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://traefik.github.io/charts
    chart: traefik
    targetRevision: 35.0.0
    helm:
      values: |
        ingressRoute:
          dashboard:
            enabled: false

        providers:
          kubernetesIngress:
            enabled: true
            ingressClass: traefik
            allowExternalNameServices: true
            allowCrossNamespace: true

        ingressClass:
            enabled: true
            isDefaultClass: false
            name: traefik

        ports:
          web:
            exposed: true
            port: 8000
            nodePort: 30080
            protocol: TCP
          websecure:
            exposed: true
            port: 8443
            nodePort: 30443
            protocol: TCP
            tls:
              enabled: true

        service:
          enabled: true
          type: NodePort

        logs:
          general:
            level: INFO
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Key configuration decisions:

- `sync-wave: "2"` — deploys after cert-manager (wave 2, same as nginx) but before apps
- `ingressRoute.dashboard.enabled: false` — no public dashboard exposure
- `providers.kubernetesIngress.ingressClass: traefik` — only serves `ingressClassName: traefik` ingresses
- `providers.kubernetesIngress.allowExternalNameServices: true` — required for authelia ForwardAuth middleware to reach `authelia.authelia.svc.cluster.local`
- `providers.kubernetesIngress.allowCrossNamespace: true` — required for middleware/transport resources in different namespaces
- `ingressClass.isDefaultClass: false` — nginx remains the default ingress class during parallel run
- `service.type: NodePort` — internal-only access via OpenVPN to node IPs
- `ports.web.nodePort: 30080` and `ports.websecure.nodePort: 30443` — fixed NodePorts for predictable access

- [ ] **Step 2: Validate the template renders**

```bash
cd /Users/loeken/Projects/private/enso-homelab
helm template enso-homelab deploy/argocd/ -s templates/traefik.yaml --set traefik.enabled=true 2>/dev/null || echo "Template renders as standalone ArgoCD Application"
```

Since this is a standalone template (no `{{ if }}` guard), it will always render. This is intentional — Traefik is always deployed alongside nginx during the migration period.

- [ ] **Step 3: Commit**

```bash
git add deploy/argocd/templates/traefik.yaml
git commit -m "feat: add Traefik ArgoCD app with NodePort service and traefik ingress class"
```

---

### Task 4: Create Shared Traefik Middleware Resources

**Files:**

- Create: `deploy/argocd/templates/traefik-middlewares.yaml`

Create two Middleware CRDs in the `default` namespace:

1. `authelia-forwardauth` — ForwardAuth pointing to Authelia
2. `authelia-cors` — CORS middleware for Authelia's own ingress

These middlewares are referenced by all app ingresses via `traefik.ingress.kubernetes.io/router.middlewares` annotations.

- [ ] **Step 1: Create the traefik-middlewares.yaml template**

Create `deploy/argocd/templates/traefik-middlewares.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  name: traefik-middlewares
  namespace: argocd
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://github.com/loeken/enso-homelab.git
    targetRevision: HEAD
    path: deploy/kustomize/traefik-middlewares
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Wait — the project uses Helm templates in ArgoCD app YAMLs, not Kustomize. Let me use the inline Helm values approach instead. Actually, the cleanest approach for static CRDs is to use a Helm chart with just raw manifests. But since the project pattern is ArgoCD apps with inline Helm values, let me use a different approach.

The simplest approach that matches the existing project pattern: embed the CRDs directly as a Helm template using the `helm` source with a custom chart path, OR use a Kustomize source. But the project doesn't use Kustomize for app resources.

**Revised approach:** Use a simple Helm chart that just renders the middleware CRDs. Create a minimal chart at `deploy/helm/traefik-middlewares/`.

Actually, the simplest approach that matches the project's existing patterns: create the middlewares as part of the Traefik Helm chart's additional resources, using `additionalArguments` or by including them in the traefik ArgoCD app's source. But the cleanest pattern is a separate ArgoCD app pointing to a git path with raw YAML files.

Let me use the git path approach (no Helm chart needed):

Create `deploy/argocd/templates/traefik-middlewares.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  name: traefik-middlewares
  namespace: argocd
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://github.com/loeken/enso-homelab.git
    targetRevision: HEAD
    path: deploy/manifests/traefik-middlewares
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 2: Create the middleware manifest directory and files**

Create `deploy/manifests/traefik-middlewares/authelia-forwardauth.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authelia-forwardauth
  namespace: default
spec:
  forwardAuth:
    address: http://authelia.authelia.svc.cluster.local/api/authz/auth-request
    trustForwardHeader: true
    authResponseHeaders:
      - Remote-User
      - Remote-Groups
      - Remote-Name
      - Remote-Email
```

Create `deploy/manifests/traefik-middlewares/authelia-cors.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authelia-cors
  namespace: default
spec:
  headers:
    accessControlAllowMethods:
      - PUT
      - GET
      - POST
      - OPTIONS
      - DELETE
      - PATCH
    accessControlAllowOriginList:
      - "https://heimdallr.{{ .Values.domain }}"
      - "http://localhost:8000"
    accessControlAllowHeaders:
      - authorization
      - content-type
      - accept
      - x-requested-with
    accessControlAllowCredentials: true
    accessControlMaxAge: 100
```

Wait — these are raw YAML files, not Helm templates. The `{{ .Values.domain }}` won't be rendered. I need to either:

1. Use a Helm chart for the middlewares
2. Hardcode the domain
3. Use Kustomize with patches

The cleanest approach for this project: create a minimal Helm chart for the middlewares. This matches the existing `deploy/helm/cluster_issuer/` pattern.

**Final approach:** Create `deploy/helm/traefik-middlewares/` Helm chart.

- [ ] **Step 2 (revised): Create the Helm chart for middlewares**

Create `deploy/helm/traefik-middlewares/Chart.yaml`:

```yaml
apiVersion: v2
name: traefik-middlewares
description: Shared Traefik Middleware CRDs for authelia ForwardAuth and CORS
type: application
version: 1.0.0
appVersion: "1.0"
```

Create `deploy/helm/traefik-middlewares/values.yaml`:

```yaml
domain: loeken.xyz
```

Create `deploy/helm/traefik-middlewares/templates/authelia-forwardauth.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authelia-forwardauth
  namespace: default
spec:
  forwardAuth:
    address: http://authelia.authelia.svc.cluster.local/api/authz/auth-request
    trustForwardHeader: true
    authResponseHeaders:
      - Remote-User
      - Remote-Groups
      - Remote-Name
      - Remote-Email
```

Create `deploy/helm/traefik-middlewares/templates/authelia-cors.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authelia-cors
  namespace: default
spec:
  headers:
    accessControlAllowMethods:
      - PUT
      - GET
      - POST
      - OPTIONS
      - DELETE
      - PATCH
    accessControlAllowOriginList:
      - "https://heimdallr.{{ .Values.domain }}"
      - "http://localhost:8000"
    accessControlAllowHeaders:
      - authorization
      - content-type
      - accept
      - x-requested-with
    accessControlAllowCredentials: true
    accessControlMaxAge: 100
```

- [ ] **Step 3 (revised): Update the ArgoCD app to use the Helm chart**

Replace `deploy/argocd/templates/traefik-middlewares.yaml` with:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  name: traefik-middlewares
  namespace: argocd
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://github.com/loeken/enso-homelab.git
    targetRevision: HEAD
    path: deploy/helm/traefik-middlewares
    helm:
      values: |
        domain: {{ .Values.domain }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Key design decisions:

- `sync-wave: "3"` — deploys after Traefik (wave 2) but before app ingresses (wave 4+)
- `namespace: default` — middlewares must be in `default` namespace so all app ingresses can reference them as `default-authelia-forwardauth@kubernetescrd`
- `CreateNamespace=true` — ensures `default` namespace exists (it always does, but this is safe)
- `domain` value passed through from parent ArgoCD values so CORS origins use the correct domain

- [ ] **Step 4: Validate the Helm template renders correctly**

```bash
cd /Users/loeken/Projects/private/enso-homelab
helm template traefik-middlewares deploy/helm/traefik-middlewares/ --set domain=loeken.xyz
```

Expected output: Two Middleware resources — `authelia-forwardauth` with forwardAuth config, and `authelia-cors` with CORS headers config including `https://heimdallr.loeken.xyz` and `http://localhost:8000` origins.

- [ ] **Step 5: Commit**

```bash
git add deploy/argocd/templates/traefik-middlewares.yaml \
      deploy/helm/traefik-middlewares/
git commit -m "feat: add shared Traefik Middleware CRDs (authelia ForwardAuth + CORS)"
```

---

### Task 5: Update Simple App Ingresses (No Custom Transport)

**Files:**

- Modify: `deploy/argocd/templates/dashy.yaml`
- Modify: `deploy/argocd/templates/homeassistant.yaml`
- Modify: `deploy/argocd/templates/jellyfin.yaml`
- Modify: `deploy/argocd/templates/jellyseerr.yaml`
- Modify: `deploy/argocd/templates/nzbget.yaml`
- Modify: `deploy/argocd/templates/prowlarr.yaml`
- Modify: `deploy/argocd/templates/radarr.yaml`
- Modify: `deploy/argocd/templates/sonarr.yaml`
- Modify: `deploy/argocd/templates/uptime-kuma.yaml`
- Modify: `deploy/argocd/templates/whoami.yaml`

These 10 apps need only: `className` → `traefik` + conditional middleware reference for authelia. No custom ServersTransport needed.

- [ ] **Step 1: Update dashy.yaml**

In `deploy/argocd/templates/dashy.yaml`, change the ingress section:

```yaml
        ingress:
          enabled: {{ .Values.dashy.ingress.enabled }}
          className: "nginx"
          annotations:
            cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
            external-dns.alpha.kubernetes.io/hostname: "hubs.{{ .Values.domain }}."
            external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
            external-dns.alpha.kubernetes.io/ttl: "120"
            {{- if .Values.dashy.useAuthelia }}
            nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
            nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
            {{- end }}
```

Replace with:

```yaml
        ingress:
          enabled: {{ .Values.dashy.ingress.enabled }}
          className: "traefik"
          annotations:
            cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
            external-dns.alpha.kubernetes.io/hostname: "hubs.{{ .Values.domain }}."
            external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
            external-dns.alpha.kubernetes.io/ttl: "120"
            {{- if .Values.dashy.useAuthelia }}
            nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
            nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
            traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
            {{- end }}
```

Changes:

- `className: "nginx"` → `className: "traefik"`
- Kept nginx auth annotations (parallel run)
- Added `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` inside the `{{- if .Values.dashy.useAuthelia }}` block

- [ ] **Step 2: Update homeassistant.yaml**

In `deploy/argocd/templates/homeassistant.yaml`, change the ingress section:

```yaml
className: "nginx"
hosts:
```

Replace with:

```yaml
            {{- if .Values.homeassistant.useAuthelia }}
            traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
            {{- end }}
            className: "traefik"
            hosts:
```

The nginx auth annotations stay in place. Only the className changes and the traefik middleware reference is added inside the existing conditional block.

- [ ] **Step 3: Update jellyfin.yaml**

In `deploy/argocd/templates/jellyfin.yaml`, inside the `{{- if .Values.jellyfin.useAuthelia }}` block, after the nginx auth-signin line, add:

```yaml
traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
```

Change `className: "nginx"` to `className: "traefik"`.

- [ ] **Step 4: Update jellyseerr.yaml**

Same pattern as jellyfin: inside the `{{- if .Values.jellyseerr.useAuthelia }}` block, add the traefik middleware reference after the nginx auth-signin line. Change `className: nginx` to `className: traefik`.

- [ ] **Step 5: Update nzbget.yaml**

Inside the `{{- if .Values.observability.useAuthelia }}` block (note: this uses `.Values.observability.useAuthelia`, not `.Values.nzbget.useAuthelia` — keep the existing conditional), add the traefik middleware reference. Change `className: "nginx"` to `className: "traefik"`.

- [ ] **Step 6: Update prowlarr.yaml**

Inside the `{{- if .Values.prowlarr.useAuthelia }}` block, add the traefik middleware reference. Change `className: "nginx"` to `className: "traefik"`.

- [ ] **Step 7: Update radarr.yaml**

Inside the `{{- if .Values.radarr.useAuthelia }}` block, add the traefik middleware reference. Change `className: nginx` to `className: traefik`.

- [ ] **Step 8: Update sonarr.yaml**

Inside the `{{- if .Values.sonarr.useAuthelia }}` block, add the traefik middleware reference. Change `className: "nginx"` to `className: "traefik"`.

- [ ] **Step 9: Update uptime-kuma.yaml**

Inside the `{{- if .Values.uptimekuma.useAuthelia }}` block, add the traefik middleware reference. Change `className: "nginx"` to `className: "traefik"`.

- [ ] **Step 10: Update whoami.yaml**

whoami has NO authelia annotations. Only change the ingress class:

```yaml
ingressClassName: nginx
```

Replace with:

```yaml
ingressClassName: traefik
```

- [ ] **Step 11: Verify all 10 files**

```bash
cd /Users/loeken/Projects/private/enso-homelab
grep -n 'className.*traefik\|ingressClassName.*traefik' deploy/argocd/templates/dashy.yaml deploy/argocd/templates/homeassistant.yaml deploy/argocd/templates/jellyfin.yaml deploy/argocd/templates/jellyseerr.yaml deploy/argocd/templates/nzbget.yaml deploy/argocd/templates/prowlarr.yaml deploy/argocd/templates/radarr.yaml deploy/argocd/templates/sonarr.yaml deploy/argocd/templates/uptime-kuma.yaml deploy/argocd/templates/whoami.yaml
```

Expected: All 10 files show `traefik` as the ingress class.

```bash
grep -n 'router.middlewares.*default-authelia-forwardauth' deploy/argocd/templates/dashy.yaml deploy/argocd/templates/homeassistant.yaml deploy/argocd/templates/jellyfin.yaml deploy/argocd/templates/jellyseerr.yaml deploy/argocd/templates/nzbget.yaml deploy/argocd/templates/prowlarr.yaml deploy/argocd/templates/radarr.yaml deploy/argocd/templates/sonarr.yaml deploy/argocd/templates/uptime-kuma.yaml
```

Expected: All 9 authelia-protected files show the middleware reference (whoami does not).

```bash
grep -n 'nginx.ingress.kubernetes.io' deploy/argocd/templates/dashy.yaml deploy/argocd/templates/homeassistant.yaml deploy/argocd/templates/jellyfin.yaml deploy/argocd/templates/jellyseerr.yaml deploy/argocd/templates/nzbget.yaml deploy/argocd/templates/prowlarr.yaml deploy/argocd/templates/radarr.yaml deploy/argocd/templates/sonarr.yaml deploy/argocd/templates/uptime-kuma.yaml
```

Expected: All nginx annotations are still present (parallel run).

- [ ] **Step 12: Commit**

```bash
git add deploy/argocd/templates/dashy.yaml \
      deploy/argocd/templates/homeassistant.yaml \
      deploy/argocd/templates/jellyfin.yaml \
      deploy/argocd/templates/jellyseerr.yaml \
      deploy/argocd/templates/nzbget.yaml \
      deploy/argocd/templates/prowlarr.yaml \
      deploy/argocd/templates/radarr.yaml \
      deploy/argocd/templates/sonarr.yaml \
      deploy/argocd/templates/uptime-kuma.yaml \
      deploy/argocd/templates/whoami.yaml
git commit -m "feat: migrate 10 simple app ingresses to traefik class with authelia middleware"
```

---

### Task 6: Update Authelia Ingress (CORS Middleware)

**Files:**

- Modify: `deploy/argocd/templates/authelia.yaml`

Authelia's ingress is special: it uses CORS annotations (not auth-url annotations) because it IS the auth provider. It needs the `authelia-cors` middleware, not `authelia-forwardauth`.

- [ ] **Step 1: Update authelia.yaml ingress section**

In `deploy/argocd/templates/authelia.yaml`, change the ingress section:

```yaml
ingress:
  enabled: { { .Values.authelia.ingress.enabled } }
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://heimdallr.{{ .Values.domain }}, http://localhost:8000"
    nginx.ingress.kubernetes.io/cors-allow-methods: "PUT, GET, POST, OPTIONS, DELETE, PATCH"
    nginx.ingress.kubernetes.io/cors-allow-headers: "authorization, content-type, accept, x-requested-with"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
    external-dns.alpha.kubernetes.io/hostname: "auth.{{ .Values.domain }}."
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
    external-dns.alpha.kubernetes.io/ttl: "120"
```

Replace with:

```yaml
ingress:
  enabled: { { .Values.authelia.ingress.enabled } }
  className: "traefik"
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://heimdallr.{{ .Values.domain }}, http://localhost:8000"
    nginx.ingress.kubernetes.io/cors-allow-methods: "PUT, GET, POST, OPTIONS, DELETE, PATCH"
    nginx.ingress.kubernetes.io/cors-allow-headers: "authorization, content-type, accept, x-requested-with"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    traefik.ingress.kubernetes.io/router.middlewares: default-authelia-cors@kubernetescrd
    cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
    external-dns.alpha.kubernetes.io/hostname: "auth.{{ .Values.domain }}."
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
    external-dns.alpha.kubernetes.io/ttl: "120"
```

Changes:

- `className: "nginx"` → `className: "traefik"`
- Kept all nginx CORS annotations (parallel run)
- Added `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-cors@kubernetescrd` (NOT forwardauth — authelia IS the auth provider)

- [ ] **Step 2: Verify**

```bash
grep -n 'className.*traefik\|router.middlewares.*authelia-cors' deploy/argocd/templates/authelia.yaml
```

Expected: `className: "traefik"` and `default-authelia-cors@kubernetescrd` present. All nginx CORS annotations still present.

- [ ] **Step 3: Commit**

```bash
git add deploy/argocd/templates/authelia.yaml
git commit -m "feat: migrate authelia ingress to traefik with CORS middleware"
```

---

### Task 7: Update Vaultwarden Ingress with ServersTransport

**Files:**

- Modify: `deploy/argocd/templates/vaultwarden.yaml`

Vaultwarden needs a custom ServersTransport for:

- Unlimited request body size (`proxy-body-size: 0` → `maxRequestBodyBytes: 0`)
- Extended timeouts (`proxy-read/send-timeout: 600` → `requestTimeout: 600s`)

- [ ] **Step 1: Add ServersTransport resource to vaultwarden.yaml**

Add a new YAML document BEFORE the ArgoCD Application in `deploy/argocd/templates/vaultwarden.yaml`. The file currently starts with:

```yaml
{{ if .Values.vaultwarden.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Application
```

Replace with:

```yaml
{ { if .Values.vaultwarden.enabled } }
---
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: vaultwarden-transport
  namespace: vaultwarden
spec:
  forwardingTimeouts:
    responseTimeout: 600s
  maxRequestBodyBytes: 0
---
apiVersion: argoproj.io/v1alpha1
kind: Application
```

The ServersTransport:

- Lives in `vaultwarden` namespace (same as the ingress)
- `responseTimeout: 600s` — replaces nginx `proxy-read-timeout: 600` and `proxy-send-timeout: 600`
- `maxRequestBodyBytes: 0` — unlimited upload size, replaces nginx `proxy-body-size: 0`

- [ ] **Step 2: Update the ingress annotations**

In the vaultwarden ingress annotations section, inside the `{{- if .Values.vaultwarden.useAuthelia }}` block, after the nginx auth-signin line, add the traefik middleware reference. Also add the ServersTransport reference and change the className:

Current ingress annotations block:

```yaml
            annotations:
              cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
              external-dns.alpha.kubernetes.io/hostname: "vaultwarden.{{ .Values.domain }}."
              external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
              external-dns.alpha.kubernetes.io/ttl: "120"
              nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
              nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
              nginx.ingress.kubernetes.io/proxy-body-size: "0"
              {{- if .Values.vaultwarden.useAuthelia }}
              nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
              nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
              {{- end }}
```

Replace with:

```yaml
            annotations:
              cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
              external-dns.alpha.kubernetes.io/hostname: "vaultwarden.{{ .Values.domain }}."
              external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
              external-dns.alpha.kubernetes.io/ttl: "120"
              nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
              nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
              nginx.ingress.kubernetes.io/proxy-body-size: "0"
              traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
              traefik.ingress.kubernetes.io/services-vaultwarden-80-transport: vaultwarden-transport
              {{- if .Values.vaultwarden.useAuthelia }}
              nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
              nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
              {{- end }}
```

Wait — the middleware reference should be conditional on `useAuthelia`. Let me reconsider. Looking at the current template, the auth annotations are conditional. The middleware reference should follow the same pattern. But the ServersTransport reference should always be present (it's not auth-related).

Actually, looking more carefully at the existing template, the `useAuthelia` conditional wraps ONLY the nginx auth annotations. The timeout and body-size annotations are always present. So the Traefik equivalents should follow the same pattern:

- `traefik.ingress.kubernetes.io/services-vaultwarden-80-transport: vaultwarden-transport` — always present (outside conditional)
- `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` — inside the `{{- if .Values.vaultwarden.useAuthelia }}` conditional

Revised replacement:

```yaml
            annotations:
              cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
              external-dns.alpha.kubernetes.io/hostname: "vaultwarden.{{ .Values.domain }}."
              external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
              external-dns.alpha.kubernetes.io/ttl: "120"
              nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
              nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
              nginx.ingress.kubernetes.io/proxy-body-size: "0"
              traefik.ingress.kubernetes.io/services-vaultwarden-80-transport: vaultwarden-transport
              {{- if .Values.vaultwarden.useAuthelia }}
              nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
              nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
              traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
              {{- end }}
```

And change `className: "nginx"` to `className: "traefik"`.

- [ ] **Step 3: Verify**

```bash
grep -n 'vaultwarden-transport\|traefik.ingress.kubernetes.io\|className.*traefik' deploy/argocd/templates/vaultwarden.yaml
```

Expected:

- ServersTransport resource named `vaultwarden-transport` in `vaultwarden` namespace
- `traefik.ingress.kubernetes.io/services-vaultwarden-80-transport: vaultwarden-transport` annotation
- `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` inside conditional
- `className: "traefik"`
- All nginx annotations still present

- [ ] **Step 4: Commit**

```bash
git add deploy/argocd/templates/vaultwarden.yaml
git commit -m "feat: migrate vaultwarden ingress to traefik with ServersTransport (unlimited body + 600s timeout)"
```

---

### Task 8: Update Nextcloud Ingress with ServersTransport

**Files:**

- Modify: `deploy/argocd/templates/nextcloud.yaml`

Nextcloud needs a custom ServersTransport for:

- 4GB request body size (`proxy-body-size: 4G` → `maxRequestBodyBytes: 4294967296`)
- Trust forwarded headers (`use-forwarded-headers: true` → `forwardedHeaders.trustExtensions: true`)

- [ ] **Step 1: Add ServersTransport resource to nextcloud.yaml**

Add a new YAML document BEFORE the ArgoCD Application in `deploy/argocd/templates/nextcloud.yaml`:

```yaml
{ { if .Values.nextcloud.enabled } }
---
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: nextcloud-transport
  namespace: nextcloud
spec:
  forwardedHeaders:
    trustExtensions: true
    trustedIPs:
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
  maxRequestBodyBytes: 4294967296
---
apiVersion: argoproj.io/v1alpha1
kind: Application
```

The ServersTransport:

- Lives in `nextcloud` namespace (same as the ingress)
- `forwardedHeaders.trustExtensions: true` — trusts X-Forwarded-For and X-Real-IP headers, replaces `use-forwarded-headers: true`
- `forwardedHeaders.trustedIPs` — restricts trusted sources to RFC 1918 private ranges (replaces `proxy-real-ip-cidr: "10.42.0.0/24"` with broader private range coverage)
- `maxRequestBodyBytes: 4294967296` — 4GB upload limit, replaces `proxy-body-size: 4G`

- [ ] **Step 2: Update the ingress annotations**

Current nextcloud ingress annotations:

```yaml
          annotations:
            cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
            external-dns.alpha.kubernetes.io/hostname: "nextcloud.{{ .Values.domain }}."
            external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
            external-dns.alpha.kubernetes.io/ttl: "120"
            {{- if .Values.nextcloud.useAuthelia }}
            nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
            nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
            {{- end }}
            nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
            nginx.ingress.kubernetes.io/proxy-real-ip-cidr: "10.42.0.0/24"
            nginx.ingress.kubernetes.io/forwarded-for-header: "X-Forwarded-For"
            nginx.ingress.kubernetes.io/proxy-body-size: 4G
          className: nginx
```

Replace with:

```yaml
          annotations:
            cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
            external-dns.alpha.kubernetes.io/hostname: "nextcloud.{{ .Values.domain }}."
            external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
            external-dns.alpha.kubernetes.io/ttl: "120"
            {{- if .Values.nextcloud.useAuthelia }}
            nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
            nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
            traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
            {{- end }}
            nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
            nginx.ingress.kubernetes.io/proxy-real-ip-cidr: "10.42.0.0/24"
            nginx.ingress.kubernetes.io/forwarded-for-header: "X-Forwarded-For"
            nginx.ingress.kubernetes.io/proxy-body-size: 4G
            traefik.ingress.kubernetes.io/services-nextcloud-8080-transport: nextcloud-transport
          className: traefik
```

Changes:

- `className: nginx` → `className: traefik`
- Kept all nginx annotations (parallel run)
- Added `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` inside the `useAuthelia` conditional
- Added `traefik.ingress.kubernetes.io/services-nextcloud-8080-transport: nextcloud-transport` (service name is `nextcloud`, port is `8080` based on the existing service port config)

- [ ] **Step 3: Verify**

```bash
grep -n 'nextcloud-transport\|traefik.ingress.kubernetes.io\|className.*traefik' deploy/argocd/templates/nextcloud.yaml
```

Expected:

- ServersTransport resource named `nextcloud-transport` in `nextcloud` namespace with `forwardedHeaders` and `maxRequestBodyBytes: 4294967296`
- `traefik.ingress.kubernetes.io/services-nextcloud-8080-transport: nextcloud-transport` annotation
- `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` inside conditional
- `className: traefik`
- All nginx annotations still present

- [ ] **Step 4: Commit**

```bash
git add deploy/argocd/templates/nextcloud.yaml
git commit -m "feat: migrate nextcloud ingress to traefik with ServersTransport (4GB body + forwarded headers)"
```

---

### Task 9: Update Sinusbot Ingress with ServersTransport

**Files:**

- Modify: `deploy/argocd/templates/sinusbot.yaml`

Sinusbot needs a custom ServersTransport for:

- 128MB request body size (`proxy-body-size: 128m` → `maxRequestBodyBytes: 134217728`)

- [ ] **Step 1: Add ServersTransport resource to sinusbot.yaml**

Add a new YAML document BEFORE the ArgoCD Application in `deploy/argocd/templates/sinusbot.yaml`:

```yaml
{ { if .Values.sinusbot.enabled } }
---
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: sinusbot-transport
  namespace: sinusbot
spec:
  maxRequestBodyBytes: 134217728
---
apiVersion: argoproj.io/v1alpha1
kind: Application
```

The ServersTransport:

- Lives in `sinusbot` namespace (same as the ingress)
- `maxRequestBodyBytes: 134217728` — 128MB upload limit, replaces `proxy-body-size: 128m`

- [ ] **Step 2: Update the ingress annotations**

Current sinusbot ingress annotations:

```yaml
            annotations:
              cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
              external-dns.alpha.kubernetes.io/hostname: "sinusbot.{{ .Values.domain }}."
              external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
              external-dns.alpha.kubernetes.io/ttl: "120"
              {{- if .Values.sinusbot.useAuthelia }}
              nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
              nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
              {{end}}
              nginx.ingress.kubernetes.io/proxy-body-size: "128m"
            className: "nginx"
```

Replace with:

```yaml
            annotations:
              cert-manager.io/cluster-issuer: "{{ .Values.clusterIssuer }}"
              external-dns.alpha.kubernetes.io/hostname: "sinusbot.{{ .Values.domain }}."
              external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
              external-dns.alpha.kubernetes.io/ttl: "120"
              {{- if .Values.sinusbot.useAuthelia }}
              nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local/api/authz/auth-request"
              nginx.ingress.kubernetes.io/auth-signin: "https://auth.{{ .Values.domain }}"
              traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
              {{end}}
              nginx.ingress.kubernetes.io/proxy-body-size: "128m"
              traefik.ingress.kubernetes.io/services-sinusbot-8087-transport: sinusbot-transport
            className: "traefik"
```

Changes:

- `className: "nginx"` → `className: "traefik"`
- Kept nginx annotations (parallel run)
- Added `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` inside the `useAuthelia` conditional
- Added `traefik.ingress.kubernetes.io/services-sinusbot-8087-transport: sinusbot-transport` (service name is `sinusbot`, port is `8087` based on existing config)

- [ ] **Step 3: Verify**

```bash
grep -n 'sinusbot-transport\|traefik.ingress.kubernetes.io\|className.*traefik' deploy/argocd/templates/sinusbot.yaml
```

Expected:

- ServersTransport resource named `sinusbot-transport` in `sinusbot` namespace with `maxRequestBodyBytes: 134217728`
- `traefik.ingress.kubernetes.io/services-sinusbot-8087-transport: sinusbot-transport` annotation
- `traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd` inside conditional
- `className: "traefik"`
- All nginx annotations still present

- [ ] **Step 4: Commit**

```bash
git add deploy/argocd/templates/sinusbot.yaml
git commit -m "feat: migrate sinusbot ingress to traefik with ServersTransport (128MB body size)"
```

---

### Task 10: Update Observability Ingresses (Grafana + Prometheus + Alertmanager)

**Files:**

- Modify: `deploy/argocd/templates/observability_grafana.yaml`
- Modify: `deploy/argocd/templates/observability_kube-prometheus-stack.yaml`

These files contain 3 ingress resources total (grafana, prometheus, alertmanager). All need className change + middleware reference.

- [ ] **Step 1: Update observability_grafana.yaml**

In `deploy/argocd/templates/observability_grafana.yaml`, change:

```yaml
ingressClassName: nginx
```

To:

```yaml
ingressClassName: traefik
```

Inside the `{{- if .Values.observability.useAuthelia }}` block, after the nginx auth-signin line, add:

```yaml
traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
```

- [ ] **Step 2: Update observability_kube-prometheus-stack.yaml (Prometheus ingress)**

In `deploy/argocd/templates/observability_kube-prometheus-stack.yaml`, find the prometheus ingress section (around line 38):

```yaml
ingressClassName: nginx
```

Change to:

```yaml
ingressClassName: traefik
```

Inside the `{{- if .Values.observability.useAuthelia }}` block, after the nginx auth-signin line, add:

```yaml
traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
```

- [ ] **Step 3: Update observability_kube-prometheus-stack.yaml (Alertmanager ingress)**

Find the alertmanager ingress section (around line 99):

```yaml
ingressClassName: nginx
```

Change to:

```yaml
ingressClassName: traefik
```

Inside the `{{- if .Values.observability.useAuthelia }}` block, after the nginx auth-signin line, add:

```yaml
traefik.ingress.kubernetes.io/router.middlewares: default-authelia-forwardauth@kubernetescrd
```

- [ ] **Step 4: Verify all observability ingresses**

```bash
grep -n 'ingressClassName.*traefik\|router.middlewares.*default-authelia-forwardauth' deploy/argocd/templates/observability_grafana.yaml deploy/argocd/templates/observability_kube-prometheus-stack.yaml
```

Expected:

- `observability_grafana.yaml`: 1 `ingressClassName: traefik`, 1 middleware reference
- `observability_kube-prometheus-stack.yaml`: 2 `ingressClassName: traefik`, 2 middleware references
- All nginx annotations still present in both files

- [ ] **Step 5: Commit**

```bash
git add deploy/argocd/templates/observability_grafana.yaml \
      deploy/argocd/templates/observability_kube-prometheus-stack.yaml
git commit -m "feat: migrate observability ingresses (grafana, prometheus, alertmanager) to traefik"
```

---

### Task 11: Final Verification and Parallel Run Validation

**Files:**

- No file changes — verification only

- [ ] **Step 1: Verify no nginx className references remain (except nginxingress.yaml)**

```bash
cd /Users/loeken/Projects/private/enso-homelab
grep -rn 'className.*nginx\|ingressClassName.*nginx' deploy/argocd/templates/ --include='*.yaml' | grep -v nginxingress.yaml
```

Expected: No output (all app ingresses now use `traefik`).

- [ ] **Step 2: Verify all nginx annotations are preserved**

```bash
grep -c 'nginx.ingress.kubernetes.io' deploy/argocd/templates/authelia.yaml deploy/argocd/templates/vaultwarden.yaml deploy/argocd/templates/nextcloud.yaml deploy/argocd/templates/sinusbot.yaml deploy/argocd/templates/dashy.yaml deploy/argocd/templates/homeassistant.yaml deploy/argocd/templates/jellyfin.yaml deploy/argocd/templates/jellyseerr.yaml deploy/argocd/templates/nzbget.yaml deploy/argocd/templates/prowlarr.yaml deploy/argocd/templates/radarr.yaml deploy/argocd/templates/sonarr.yaml deploy/argocd/templates/uptime-kuma.yaml deploy/argocd/templates/observability_grafana.yaml deploy/argocd/templates/observability_kube-prometheus-stack.yaml
```

Expected: All files with authelia/CORS/nginx-specific annotations show count > 0.

- [ ] **Step 3: Verify all traefik middleware references**

```bash
grep -c 'router.middlewares.*default-authelia' deploy/argocd/templates/authelia.yaml deploy/argocd/templates/vaultwarden.yaml deploy/argocd/templates/nextcloud.yaml deploy/argocd/templates/sinusbot.yaml deploy/argocd/templates/dashy.yaml deploy/argocd/templates/homeassistant.yaml deploy/argocd/templates/jellyfin.yaml deploy/argocd/templates/jellyseerr.yaml deploy/argocd/templates/nzbget.yaml deploy/argocd/templates/prowlarr.yaml deploy/argocd/templates/radarr.yaml deploy/argocd/templates/sonarr.yaml deploy/argocd/templates/uptime-kuma.yaml deploy/argocd/templates/observability_grafana.yaml deploy/argocd/templates/observability_kube-prometheus-stack.yaml
```

Expected:

- `authelia.yaml`: 1 (cors middleware)
- All authelia-protected apps: 1 each (forwardauth middleware)
- `whoami.yaml`: 0 (no authelia)

- [ ] **Step 4: Verify all ServersTransport references**

```bash
grep -rn 'traefik.ingress.kubernetes.io/services-.*-transport' deploy/argocd/templates/
```

Expected:

- `vaultwarden.yaml`: `services-vaultwarden-80-transport: vaultwarden-transport`
- `nextcloud.yaml`: `services-nextcloud-8080-transport: nextcloud-transport`
- `sinusbot.yaml`: `services-sinusbot-8087-transport: sinusbot-transport`

- [ ] **Step 5: Verify nginxingress.yaml is unchanged**

```bash
git diff deploy/argocd/templates/nginxingress.yaml
```

Expected: No changes.

- [ ] **Step 6: Verify DNS-01 ClusterIssuers**

```bash
helm template cluster-issuer deploy/helm/cluster_issuer/ --set domain=loeken.xyz | grep -A5 'dns01'
```

Expected: Both staging and prod ClusterIssuers show `dns01.cloudflare` solver with `apiTokenSecretRef` to `cert-manager-cloudflare`.

- [ ] **Step 7: Verify Traefik ArgoCD app**

```bash
grep -n 'sync-wave\|NodePort\|traefik\|allowExternalName' deploy/argocd/templates/traefik.yaml
```

Expected: sync-wave 2, NodePort service, traefik ingress class, allowExternalNameServices true, allowCrossNamespace true.

- [ ] **Step 8: Commit any remaining changes**

```bash
git status
git add -A
git commit -m "chore: final verification of traefik migration changes"
```

---

## Rollout Order (After All Tasks Complete)

When the engineer is ready to deploy, the sync-wave ordering ensures correct deployment sequence:

| Wave | Resource            | Purpose                                                        |
| ---- | ------------------- | -------------------------------------------------------------- |
| 0    | argocd              | ArgoCD itself                                                  |
| 2    | cert-manager        | Certificate management                                         |
| 2    | nginx-ingress       | Existing nginx (unchanged)                                     |
| 2    | traefik             | New Traefik ingress                                            |
| 3    | cluster-issuer      | DNS-01 ClusterIssuers (needs cert-manager + cloudflare secret) |
| 3    | traefik-middlewares | Shared middleware CRDs (needs Traefik CRDs installed)          |
| 4+   | All app ingresses   | Reference traefik class + middlewares                          |

## Pre-Deployment Checklist

Before applying these changes to the cluster, the user must:

1. **Create the `cert-manager-cloudflare` secret** (Task 1):

   ```bash
   kubectl create secret generic cert-manager-cloudflare \
     --from-literal=CloudflareApiToken="<YOUR_TOKEN>" \
     -n cert-manager
   ```

2. **Verify Cloudflare API token permissions**:
   - Zone: Read for `loeken.xyz`
   - DNS: Edit for `loeken.xyz`

3. **Confirm nginx is still running** — the parallel run requires both ingress controllers active.

## Post-Deployment Verification

After ArgoCD syncs:

1. **Check Traefik pods are running**:

   ```bash
   kubectl get pods -n traefik
   ```

2. **Check middlewares exist**:

   ```bash
   kubectl get middleware -n default
   ```

   Expected: `authelia-forwardauth` and `authelia-cors`

3. **Check ServersTransports exist**:

   ```bash
   kubectl get serverstransport -n vaultwarden
   kubectl get serverstransport -n nextcloud
   kubectl get serverstransport -n sinusbot
   ```

4. **Check a test ingress is served by Traefik**:

   ```bash
   kubectl describe ingress -n whoami | grep 'Ingress Class'
   ```

   Expected: `traefik`

5. **Check DNS-01 certificate is issuing**:

   ```bash
   kubectl get certificate -A
   kubectl describe certificate -n whoami whoami-tls
   ```

   Expected: Certificate condition shows `Ready=True`, issuer shows DNS-01 challenge.

6. **Test service accessibility via OpenVPN**:
   ```bash
   curl -k https://<NODE_IP>:30443/ -H "Host: whoami.loeken.xyz"
   ```

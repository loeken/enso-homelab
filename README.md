# ensō-homelab ○

> A minimalist, elegant, GitOps-powered homelab built for everyone — from curious self-hosters to seasoned DevOps engineers.


<table>
<tr>
<td width="80">
  <img src="./docs/img/enso_64.png" alt="ensō" width="64" />
</td>
<td>
  <strong>ensō</strong> (円相) represents absolute simplicity, completeness, and the elegance of minimal design.<br>
  This project embraces that philosophy — to create a clean, reproducible, and modular way to run a Kubernetes homelab powered by <a href="https://k3s.io">K3s</a>, <a href="https://argo-cd.readthedocs.io/">ArgoCD</a>, and your favorite open-source tools.
</td>
</tr>
</table>

## ✨ Features

- ⚙️ **GitOps-first** — Automated continuous delivery with ArgoCD  
- 🐳 **Lightweight Kubernetes** — Powered by [K3s](https://k3s.io), perfect for a NUC or VM  
- 📦 **Modular App Management** — Easily install optional apps via Helm  
- 🔐 **Secrets Management** — Integrates with Sealed Secrets (or SOPS, optional)  
- ⚡ **One-line Setup** — Bootstrap using a simple Go-based CLI tool  
- 🧠 **Interactive Wizard or Arguments** — Use `wizard` or `bootstrap` with flags  
- 📦 **Devcontainer & Dockerized** — Clone & run in a fully-defined local environment  
- 🔄 **Auto-updates via Renovate** — Stay up-to-date with GitHub Actions  
- 💡 **Beginner-Friendly** — Clear docs, sensible defaults, hackable design  

---

## 📦 Stack Overview

| Layer          | Tools                                           |
|----------------|-------------------------------------------------|
| Infrastructure | Ansible, Terraform                              |
| Kubernetes     | K3s, Helm, Kubectl, ArgoCD                      |
| Secrets        | Kubeseal (Sealed Secrets), Ansible Vault        |
| Networking     | NGINX Ingress, ExternalDNS, Cert-Manager        |
| Monitoring     | Loki, Promtail, Grafana                         |
| Dev Tools      | Go, Renovate, GitHub Actions, Devcontainer      |

---

## 🚀 Quickstart

This assumes you're running on a small Linux machine (like an Intel NUC or KVM guest) with internet access.

### 🧰 1. Requirements

- Debian-based Linux host (Debian 12 recommended)  
- Public domain (e.g. via Cloudflare, optional)  
- GitHub account with repo access  
- [Docker](https://docs.docker.com/get-docker/) installed locally (for dev)  
- [VS Code](https://code.visualstudio.com/) + Remote Containers **or** GitHub Codespaces  

## 🧩 2. Philosophy
ensō-homelab is:

Minimal — only what's needed to get running, extend as you grow

Hackable — every part can be swapped, forked, or improved

Collaborative — contributions are welcome, everything documented

Zen-inspired — like the ensō, it's open-ended and elegant by design

## 🛠️ 3. Contributing
Want to contribute or build your own flavor of ensō-homelab?

Clone the repo and run it locally via the provided devcontainer or Docker image

Use ./ensoctl wizard or ./ensoctl bootstrap to get started

Add your feature or improvement

Open a pull request, even if it's just a discussion!

Check out CONTRIBUTING.md (coming soon)

### 🔁 4. Install & Bootstrap

```bash
git clone https://github.com/loeken/enso-homelab.git
cd enso-homelab

# Option 1: Run interactive wizard (asks config questions and installs)
./ensoctl wizard

# Option 2: Pass arguments directly to bootstrap
./ensoctl bootstrap --provider=kvm --dns=cloudflare --domain=example.com
```

The CLI will:
- Check for existing config or prompt for inputs  
- Provision the host (via Ansible or Terraform)  
- Install K3s  
- Install ArgoCD  
- Deploy ArgoCD apps using GitOps  
- Optionally seal secrets  
- Setup ingress + TLS if domain is configured  


## 🌀 5. About the Name
Ensō (円相) is a Zen symbol of elegance, completeness, and simplicity.
This project aspires to the same values — a homelab that is complete, yet minimal.

## 📄 6. License
MIT

Built with ❤️ by @loeken
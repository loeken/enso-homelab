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
- 🔐 **Secrets Management** — Integrates with Sealed Secrets  
- ⚡ **Minimal Setup** — Create a repo, set secrets, trigger install  
- 🔬 **Trigger with Comments** — Use `/install-k3s` or `/install-proxmox` to bootstrap  
- 📊 **Auto-updates via Renovate** — Stay up-to-date with GitHub Actions  
- 💡 **Beginner-Friendly** — Clear docs, sensible defaults, hackable design  

---

## 📦 Stack Overview

| Layer          | Tools                                           |
|----------------|-------------------------------------------------|
| Infrastructure | Terraform, GitHub Actions                       |
| Kubernetes     | K3s, Helm, Kubectl, ArgoCD                      |
| Secrets        | Kubeseal (Sealed Secrets), GitHub Secrets       |
| Networking     | NGINX Ingress, ExternalDNS, Cert-Manager        |
| Monitoring     | Loki, Promtail, Grafana                         |
| Dev Tools      | Renovate, GitHub CLI, GitHub Actions            |

---

## 🚀 Quickstart

This assumes you're running on a small Linux machine (like an Intel NUC or KVM guest) with internet access.

### 🛠️ 1. Requirements

- Debian-based Linux host (Debian 12 recommended)  
- Public domain (e.g., via Cloudflare, optional)  
- GitHub account with a public repo (or private if you have a paid account).  
  - This repo expects "environments" for secrets to be available ([GitHub Environments Documentation](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment)).
- Terraform Cloud account to store state files.  
  - Sign up at [Terraform Cloud](https://app.terraform.io/signup).  
  - Create an organization and generate a Terraform Cloud API token.

---

## 🧹 2. How it Works

1. **Create a new repo from the [enso-homelab template](https://github.com/loeken/enso-homelab)**  
2. **Wait for the onboarding issue to be auto-created**  
3. **Set required secrets using GitHub CLI or UI**  
4. **Trigger install by commenting `/install-k3s` or `/install-proxmox` on the issue**  
5. **Define which parts to use**
```
cp deploy/argocd/values.yaml.example deploy/argocd/values.yaml
nano deploy/argocd/values.yaml
git add deploy/argocd/values.yaml
git commit -m "adding values.yaml"
git push
```
6. **Run GitHub action "Check Secrets" to see which secrets to add and how**
That's it. The rest is automated.

---

## 🛠️ 3. Secrets Required

The following repository secrets must be set:

| Secret                      | Description |
|-----------------------------|-------------------------------------------------|
| `SSH_USERNAME`              | SSH user for your VM/server                     |
| `SSH_SERVER_ADDRESS`        | Public IP or hostname of the VM/server          |
| `SSH_INTERNAL_ADDRESS`      | Internal (private) IP for advertising k3s nodes |
| `SSH_SERVER_PORT`           | Custom SSH port (e.g. 60023)                    |
| `SSH_PRIVATE_KEY`           | Base64-encoded private key for SSH access       |
| `HOSTNAME`                  | Expected hostname of the target node            |
| `TF_TOKEN_app_terraform_io` | Terraform Cloud API token                       |
| `TF_CLOUD_ORGANIZATION`     | Terraform Cloud Organization Name               |
| `PAT_GITHUB_TOKEN`          | GitHub token                                    |
| `RENOVATE_TOKEN`            | Token for Renovate bot                          |

To set secrets quickly:

```bash
gh secret set SSH_USERNAME --body "loeken"
gh secret set SSH_SERVER_ADDRESS --body "94.134.58.166"
gh secret set SSH_INTERNAL_ADDRESS --body "192.168.1.185"
gh secret set SSH_SERVER_PORT --body "60023"
gh secret set HOSTNAME --body "homelab"
gh secret set SSH_PRIVATE_KEY --body "$(cat ~/.ssh/id_ed25519 | base64)"
gh secret set TF_TOKEN_app_terraform_io --body "your-tf-cloud-token"
gh secret set TF_CLOUD_ORGANIZATION --body "ime"
gh secret set PAT_GITHUB_TOKEN --body "$(gh auth token)"
gh secret set RENOVATE_TOKEN --body "your-renovate-token"
```

---

## 🎓 4. Additional Setup Steps

1. **Terraform Cloud Setup**  
   - Log in to [Terraform Cloud](https://app.terraform.io/).  
   - Create an organization (e.g., `ime`).  
   - Generate a Terraform Cloud API token and set it as the `TF_TOKEN_app_terraform_io` secret.  
   - Ensure the workspace execution mode is set to "local." This is automated in the workflow, but you can verify it in the Terraform Cloud UI.

2. **Install Dependencies Locally (Optional)**  
   If you want to run workflows locally using [`act`](https://github.com/nektos/act):  
   - Install Docker.  
   - Install `act` by following the [installation guide](https://github.com/nektos/act#installation).  
   - Run workflows locally with `act` commands.

---

## 🎓 5. Philosophy

ensō-homelab is:

- **Minimal** — only what's needed to get running, extend as you grow  
- **Hackable** — every part can be swapped, forked, or improved  
- **Collaborative** — contributions are welcome, everything documented  
- **Zen-inspired** — like the ensō, it's open-ended and elegant by design  

---

## 💪 6. Contributing

Want to contribute or build your own flavor of ensō-homelab?

- Fork or template the repo  
- Use the onboarding flow to get set up  
- Add your feature or improvement  
- Open a pull request, even if it's just a discussion!  

CONTRIBUTING.md coming soon.

---

## 🔄 7. Automation Triggers

Comment these on the onboarding issue to trigger actions:

- `/install-k3s` → Install K3s using Terraform + k3sup  
- `/install-proxmox` → Set up Proxmox on a Debian host and create a VM _(WIP)_  

---

## 🔀 8. About the Name

Ensō (円相) is a Zen symbol of elegance, completeness, and simplicity.  
This project aspires to the same values — a homelab that is complete, yet minimal.

---

## 📄 9. License

MIT

Built with ❤️ by @loeken


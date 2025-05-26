0.) reinstall server
1.) delete repository
2.) delete terraform states
3.) create new repo based on https://github.com/loeken/enso-homelab
4.) create secrets
5.) /proxmox-single comment
6.) rm local repo and clone
7.) inventory
cp deploy/ansible/proxmox/inventory.example deploy/ansible/proxmox/inventory
git add deploy/ansible/proxmox/inventory
git commit -m "add inventory file"
git push

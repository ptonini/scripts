---
name: "pedro-local"
description: "Pedro Tonini personal machine paths, credentials, and shortcuts. Not in git."
disable-model-invocation: true
---

# Pedro Tonini — Local Machine Config

## Kubeconfig files

| Environment | Kubeconfig | Context | Notes |
|---|---|---|---|
| local | `~/.kube/config-sts-lab` | `sts-lab` | Vagrant lab, usually offline |
| beta | `~/.kube/config-sts-beta` | `sts-beta` | |
| test | `~/.kube/config-sts-test` | `sts-test` | |
| ops | `~/.kube/config-sts-ops` | `sts-ops` | OIDC/dex — may require browser login in interactive sessions |
| prod | `~/.kube/config-sts-prod` | `sts-prod` | Dedicated file; context is lowercase `sts-prod` |

SSH key for K3s nodes: `~/.ssh/id_rsa`

## Gitignored var files

| Repo path | Purpose |
|---|---|
| `ansible/.env` | Local lab vars: `VM_BOX`, `BRIDGE_INTERFACE`, `NAT_GATEWAY`, `GATEWAY`, `DEFAULT_INTERFACE`, `DNS_SERVER`, `INVENTORY`, `SSH_PUB_KEY`, `VBOX_LOG_DEST` |
| `ansible/inventory/group_vars/sts_lab/local.yaml` | `k3s.context` + `k3s.kubeconfig` for the local Vagrant lab |
| `ansible/inventory/group_vars/sts_lab_lite/local.yaml` | `k3s.context` + `k3s.kubeconfig` for the local lite lab |
| `ansible/inventory/group_vars/sts_beta/local.yaml` | `k3s.context` + `k3s.kubeconfig` for the beta cluster |
| `ansible/inventory/group_vars/sts_ops/local.yaml` | `k3s.context` + `k3s.kubeconfig` for the ops cluster |
| `terraform/general/terraform.tfvars` | `kubeconfig_path`, `beta_kubeconfig_filename`, `beta_kubeconfig_context`, `ops_kubeconfig_filename`, `ops_kubeconfig_context` — all required, no defaults in `variables.tf` |
| `terraform/xen-orchestra/terraform.tfvars` | XOA auth comment only; token is in `~/.bashrc` env vars |

## Open issues / follow-up

- **AD DC AAAA REFUSED — permanent fix needed (IT team).** All three AD DCs return `REFUSED` for AAAA queries instead of `NOERROR` (empty), causing `EAI_AGAIN` in Go processes (containerd image pulls) on nodes using systemd-resolved. Workaround applied 2026-07-23: CoreDNS AAAA `rcode NOERROR` template on ops CP nodes + manual `systemd-resolved` override on ops app/storage nodes pointing to CoreDNS. Proper fix: Windows DNS policy on all DCs to return `NOERROR` for AAAA. Track as IT action item. See `docs/incidents/INC-2026-07-20-dns-ipv6.docx` for background.

## Personal rules

- **Do not suggest sending ntfy notifications.** Pedro does not use ntfy for manual notifications — skip any suggestion to curl/post to `ntfy.stsrecycle.com` as part of task completion steps.

## Personal repositories

`ptonini/scripts` (`~/Projetos/ptonini/scripts`) is a personal scripts repo on `main`. It does not follow the STS branch+PR workflow — commit and push directly to `main`. The pedro-local skill lives at `skills/pedro-local/SKILL.md` within this repo, symlinked from `~/.agents/skills/pedro-local/SKILL.md`.

## Session-derived rules

### Session review scope in personal repos
When a session-review is triggered while working in a personal repo or folder (e.g. `ptonini/scripts`), update **only** this personal skill (`pedro-local/SKILL.md`) — do not open branches or PRs in `sts-skills`. Edit the file directly at `~/Projetos/ptonini/scripts/skills/pedro-local/SKILL.md` and commit to `main`.

### Shell for-loop output is silently empty — use single-line commands
When running diagnostic shell commands, `for`-loop bodies consistently produce empty output in the tool results even when the loop logic is correct. Always prefer single-line, pipe-based equivalents (e.g. `dpkg -l pkg1 pkg2 | grep ^ii`, `comm -23 <(...) <(...)`, `ls /path/a /path/b 2>&1`) over loops with conditional `echo` statements.

## New machine / notebook setup (STS resources)

**Automated setup script**: `skills/sts-configure-machine` in `ptonini/scripts`.
Run `ubuntu-configure-desktop` first, then:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ptonini/scripts/main/skills/sts-configure-machine)
# or, if repo is already cloned:
~/Projetos/ptonini/scripts/skills/sts-configure-machine
```
The script copies files from hal9000 (`192.168.1.11`) over SSH — hal9000 must be on the LAN.

Manual reference for individual steps:

### 1. Cisco Secure Client VPN
- **Client**: Cisco Secure Client 5.1.14.145 — installed via web deploy (no apt package).
  Open a browser to `https://vpn.stsrecycle.com` while on a network that can reach it, or copy the installer from an existing machine (`/opt/cisco/secureclient/`).
- **Server**: `vpn.stsrecycle.com` (HTTPS/443, public IP `24.32.55.250`)
- **Auth**: AD username/password (no client certificate, no SDI token)
- **Pushed routes**: `10.1.0.0/16`, `10.2.0.0/16`, `192.147.0.0/20`, `192.147.20.0/24`, `192.147.30.0/24`, `192.147.48.0/21`
- **Pushed DNS**: `10.1.32.20`, `10.1.32.21` — domain search `STSRECYCLE.LOCAL`
- **VPN pool**: `10.1.252.x/24`
- AutoConnectOnStart and LocalLanAccess are enabled in the client profile.

### 2. Custom home CA certificate
- Source: copy `home-ca.crt` from `~hal9000:/usr/local/share/ca-certificates/home-ca.crt`
  (CN=home-ca, self-signed, valid until 2034-12-09)
- Install:
  ```bash
  sudo cp home-ca.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
  ```

### 3. SSH key
- **Key used for K3s nodes and GitHub**: `~/.ssh/id_rsa` (3072-bit RSA, comment `ptonini@hal9000`)
- Copy the keypair from the existing machine, or generate a new one and register it:
  - GitHub: `gh ssh-key add ~/.ssh/id_rsa.pub --title "<hostname>"`
  - K3s nodes: deploy via Ansible or add to `~/.ssh/authorized_keys` on each node
- Add this block to `~/.ssh/config`:
  ```
  Host *.corp.stsrecycle.com
  Host 10.1.32.*
      User itsupport
  ```
  (Note: existing config has a typo `stsresycle` — use `stsrecycle`.)

### 4. Kubeconfigs
- Copy all `~/.kube/config-sts-*` files from the existing machine:
  ```bash
  scp hal9000:~/.kube/config-sts-* ~/.kube/
  ```
- The `KUBECONFIG` env var is set automatically by `.bashrc` to include all `~/.kube/config*` files.

### 5. GitHub CLI
- Login with the `gh-login` alias (defined in `.bashrc` custom block):
  ```bash
  gh auth login -p ssh -s admin:org,workflow,delete_repo -w
  ```
- Required token scopes: `admin:public_key`, `delete_repo`, `gist`, `read:org`, `repo`, `workflow`

### 6. Azure CLI
- Login: `az login` → authenticate as `pedro.tonini@stsrecycle.com`
- Tenant ID: `5a47c5ca-8e59-4af3-b24a-51541d7046fe`
- Subscription: Microsoft Partner Network
- After login, the `az config` setting for dynamic extension install is applied automatically by `ubuntu-configure-desktop`.

### 7. ntfy (Ntfyr)
- Already installed by `ubuntu-configure-desktop` flatpak list (`io.github.tobagin.Ntfyr`).
- On first launch: add server `https://ntfy.stsrecycle.com` and authenticate with your ntfy token.
- Subscribe to the `ops` topic.
- Token: generate via `ntfy token add <user>` on the ntfy server (see ntfy skill), or ask the STS admin.

## ZeroTier (personal, not STS)
- Networks: `633e31d8a2ed171c` (ptonini-org-network, `10.157.24.x/24`)
- Join: `sudo zerotier-cli join 633e31d8a2ed171c` — request auth from network admin.
- Not part of STS setup; do separately as needed.

## Warp local data

Warp SQLite database (conversations, sessions, ai_queries): `~/.local/state/warp-terminal/warp.sqlite`
- Use `sqlite3` CLI or `python3`
- Key tables: `agent_conversations` (metadata, artifacts, summary), `ai_queries` (all user turns with timestamps per conversation)

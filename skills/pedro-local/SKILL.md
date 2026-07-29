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

## Warp local data

Warp SQLite database (conversations, sessions, ai_queries): `~/.local/state/warp-terminal/warp.sqlite`
- Use `sqlite3` CLI or `python3`
- Key tables: `agent_conversations` (metadata, artifacts, summary), `ai_queries` (all user turns with timestamps per conversation)

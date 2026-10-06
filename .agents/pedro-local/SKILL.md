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

- **Use standard dashes.** When generating text or code, use standard ASCII hyphens (`-`) instead of Unicode dashes (`—`, `–`, `\u2014`, `\u2013`) to ensure compatibility with all tools and parsers.

## Personal repositories

`ptonini/scripts` (`~/Projetos/ptonini/scripts`) is a personal scripts repo on `main`. It does not follow the STS branch+PR workflow — commit and push directly to `main`. The pedro-local skill lives at `.agents/pedro-local/SKILL.md` within this repo, symlinked from `~/.agents/skills/pedro-local/SKILL.md`.

## Hardware — hal9000

**Motherboard**: Gigabyte Z590 UD AC (Intel Z590 chipset, LGA1200). 3x M.2 slots: `M2P_CPU` (CPU-direct, PCIe 4.0 x4), `M2A_SB` and `M2M_SB` (chipset, PCIe 3.0 x4/x2). GPU: NVIDIA RTX 3060 (Lite Hash Rate).

**NVMe drives** (all XPG GAMMIX S70 BLADE — identify by serial + PCI address, not `/dev/nvmeX` name, which is not stable across reboots on this machine):

| Serial | Capacity | Content | M.2 slot | PCI address |
|---|---|---|---|---|
| `2N372LAG94RW` | 2TB | Windows data volume ("Jogos") | `M2P_CPU` (CPU-direct) | `02:00.0` |
| `2M422LQBDHXU` | 512GB | Windows system disk ("Sistema") + Windows-native ESP (UUID `CA29-C244`) | `M2A_SB` or `M2M_SB` (chipset) | `06:00.0` |
| `2M402LAJNBFF` | 512GB | **This Linux install** — ext4 root (UUID `ceaa83d0-f74c-494b-900b-205c7d572021`) + own ESP (UUID `93D6-1FBA`) | `M2A_SB` or `M2M_SB` (chipset) | `07:00.0` |

Exact `M2A_SB` vs `M2M_SB` assignment for the two chipset slots is unresolved — check the BIOS storage config page or PCB silkscreen if it matters.

**Boot configuration**: Linux boots from its own dedicated ESP (UUID `93D6-1FBA`) independent of the Windows disk — `/etc/fstab` and GRUB (`grub-install --bootloader-id=ubuntu`) point there. UEFI `BootOrder` is `Ubuntu` (NVRAM entry `Boot0007`) first, `Windows Boot Manager` (`Boot0000`) second, 2-second timeout. The Windows ESP (`CA29-C244`) was restored to Microsoft-only content (no leftover GRUB/shim files).

**Gotcha**: `/dev/nvmeXn1` naming is **not stable** across reboots on this machine — PCIe enumeration order shifts. Always resolve disks by UUID (`mount UUID=...`, `/etc/fstab` already does this correctly) or by serial/PCI address (`ls -l /dev/disk/by-id/`, `readlink -f /sys/class/nvme/nvmeX/device`). Never hardcode `/dev/nvme0n1` etc. in scripts or commands for this host.

## Session-derived rules

### Session review scope in personal repos
When a session-review is triggered while working in a personal repo or folder (e.g. `ptonini/scripts`), update **only** this personal skill (`pedro-local/SKILL.md`) — do not open branches or PRs in `sts-skills`. Edit the file directly at `~/Projetos/ptonini/scripts/.agents/pedro-local/SKILL.md` and commit to `main`.

### Shell for-loop output is silently empty — use single-line commands
When running diagnostic shell commands in Warp, `for`-loop bodies consistently produce empty output in the tool results even when the loop logic is correct (not yet confirmed in other agents - if loops work in Claude Desktop, drop this rule's Warp scoping). Always prefer single-line, pipe-based equivalents (e.g. `dpkg -l pkg1 pkg2 | grep ^ii`, `comm -23 <(...) <(...)`, `ls /path/a /path/b 2>&1`) over loops with conditional `echo` statements.

## New machine / notebook setup (STS resources)

**Automated setup script**: `.agents/sts-configure-machine` in `ptonini/scripts`.
Run `ubuntu-configure-desktop` first, then:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ptonini/scripts/main/.agents/sts-configure-machine)
# or, if repo is already cloned:
~/Projetos/ptonini/scripts/.agents/sts-configure-machine
```
The script copies files from hal9000 (`192.168.1.11`) over SSH — hal9000 must be on the LAN.

To load the pedro-local skill on a new machine after cloning:
```bash
ln -s ~/Projetos/ptonini/scripts/.agents/pedro-local ~/.agents/skills/pedro-local
```

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

### 8. STS repositories
Clone all STS repos under `~/Projetos/stsrecycle/`:
```bash
mkdir -p ~/Projetos/stsrecycle
cd ~/Projetos/stsrecycle
gh repo clone STS-Electronic-Recycling/.github dotgithub
gh repo clone STS-Electronic-Recycling/helm-charts
gh repo clone STS-Electronic-Recycling/sts-devops
gh repo clone STS-Electronic-Recycling/sts-platform
gh repo clone STS-Electronic-Recycling/sts-services
gh repo clone STS-Electronic-Recycling/sts-skills
gh repo clone STS-Electronic-Recycling/terraform-modules
```
Post-clone setup for `sts-devops` — copy skills and gitignored var files from hal9000:
```bash
# Skills dir is untracked (submodule removed in PR #433) — copy from hal9000
scp -r hal9000:~/Projetos/stsrecycle/sts-devops/.agents/skills ~/Projetos/stsrecycle/sts-devops/.agents/

# Gitignored var files (copy each as needed)
scp hal9000:~/Projetos/stsrecycle/sts-devops/ansible/.env                                          ~/Projetos/stsrecycle/sts-devops/ansible/.env
scp hal9000:~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_lab/local.yaml       ~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_lab/local.yaml
scp hal9000:~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_lab_lite/local.yaml  ~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_lab_lite/local.yaml
scp hal9000:~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_beta/local.yaml      ~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_beta/local.yaml
scp hal9000:~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_ops/local.yaml       ~/Projetos/stsrecycle/sts-devops/ansible/inventory/group_vars/sts_ops/local.yaml
scp hal9000:~/Projetos/stsrecycle/sts-devops/terraform/general/terraform.tfvars                    ~/Projetos/stsrecycle/sts-devops/terraform/general/terraform.tfvars
scp hal9000:~/Projetos/stsrecycle/sts-devops/terraform/xen-orchestra/terraform.tfvars              ~/Projetos/stsrecycle/sts-devops/terraform/xen-orchestra/terraform.tfvars
```
After cloning `sts-skills`, load the shared skills by symlinking into `~/.agents/skills/`:
```bash
# Link each shared skill (repeat for any skill you want loaded)
ls ~/Projetos/stsrecycle/sts-skills/ | xargs -I{} ln -sf ~/Projetos/stsrecycle/sts-skills/{} ~/.agents/skills/{}
```

## ZeroTier (personal, not STS)
- Networks: `633e31d8a2ed171c` (ptonini-org-network, `10.157.24.x/24`)
- Join: `sudo zerotier-cli join 633e31d8a2ed171c` — request auth from network admin.
- Not part of STS setup; do separately as needed.

## Local conversation history

Pedro works in more than one agent (Warp and Claude Desktop). Reconstruct work from every agent used in the period, not just one.

### Warp

Warp SQLite database (conversations, sessions, ai_queries): `~/.local/state/warp-terminal/warp.sqlite`
- Use `sqlite3` CLI or `python3` (`sqlite3` CLI is often not installed on this machine — use
  `python3 -c "import sqlite3; ..."` instead)
- Key tables: `agent_conversations` (metadata, artifacts, summary), `ai_queries` (all user turns with timestamps per conversation)
- `ai_queries` columns: `conversation_id`, `start_ts` (DATETIME), `working_directory`, `input`
  (JSON array; extract via `item['Query']['text']` for the first dict containing `"Query"`)
- `agent_conversations.summary` is JSON with `initial_query`, `title`, `initial_working_directory` —
  use `title` as a quick label for what a conversation was about

### Claude Desktop

Use the session-management tools rather than reading app storage files. They are deferred, so load
them with `ToolSearch` (`select:<name>`) first: `mcp__ccd_session_mgmt__list_sessions`,
`search_session_transcripts`, `list_events`, `export_transcript`. Session title and working
directory stand in for Warp's `title` and `working_directory`.

## STS DS Weekly Timesheet

Reconstructs a week of actual work into `STS_DS_Weekly_Timesheet_Pedro_Tonini_<date>.xlsx`
(kept in `~/Downloads`) by mining local agent conversation history (the Warp database and Claude Desktop sessions above) — no manual log needed.

**Building the week's task list:**
1. Collect user turns for the target week (Mon–Fri, or through "today" if the week is in
   progress) from every agent source: Warp `ai_queries` filtered by `date(start_ts)`, and Claude
   Desktop session events by timestamp.
2. Group turns by `conversation_id` (Desktop: session id). If a single conversation's queries span multiple calendar
   dates, split it into one entry per date.
3. Estimate hours per entry from the span between the first and last query timestamp in that
   date/conversation group. Single-query or very short groups still represent real (if brief)
   engaged time — do not report 0.
4. Exclude personal/non-work conversations (home hardware, personal networking, personal
   tooling, etc.) and the meta-conversation about building the timesheet itself, unless asked
   to include them.
5. Write one plain-language sentence per entry for the "What you worked on" column —
   specific enough that a teammate who wasn't in the room understands the outcome.

Default to real quarter-hour estimates rather than rounding up. Only round hours up to whole
numbers, or scale entries to fill 8h/day, when explicitly asked — apply the adjustment
per entry, not just to the day/week total.

**Workbook structure (Timesheet / Lists / Export / Instructions tabs)** — data validation
is strict; `openpyxl` won't raise an error for invalid values, but they'll be flagged
downstream. Check `ws.data_validations.dataValidation` on a new template before assuming
column rules, but as of this writing:
- `Timesheet!B6` (Week Ending) — must be a Friday; the `Lists!E2:E8` "Week Dates" range
  and the `G9:H17` daily-totals block both derive from this cell.
- `Timesheet!B10:B59` (Category) — list-validated against `Lists!A2:A5`, a **fixed
  four-value list**: `Project Work`, `Support`, `Overhead`, `Time Off`. Do not invent
  sub-categories (e.g. "DevOps/CI"). Map each task to the closest of the four:
  - `Support` — reactive/break-fix work, alerts, access requests, ops maintenance
  - `Project Work` — planned build-out, new capability, deliberate design/implementation
  - `Overhead` — meetings, admin, internal process
  - `Time Off` — PTO
- `Timesheet!C10:C59` (Hours) — custom-validated as `AND(C>0, C<=16, MOD(C,0.25)=0)` —
  quarter-hour increments only.
- `Timesheet!E10:E59` (Check) — formula-driven; never overwrite, it self-populates once
  A–D are filled.
- `Export` tab — flattens `Timesheet` rows via formulas referencing fixed row offsets;
  never edit it directly.

**Creating a new week's file** — copy the most recently completed week's file (not a
blank template) as the base, since it already carries correct formulas/validation and `B3`:
```bash
cp "<previous week file>.xlsx" "<new week file>.xlsx"
```
Then with `openpyxl`: set `Timesheet!B6` to the new Week Ending (Friday) date; clear existing
entries in `A10:D59` (loop, set to `None`) before writing new ones; write
`(date, category, hours, description)` starting at row 10; save — formulas in columns E
and G:H recompute automatically in Excel/LibreOffice on open.

`.xlsx` files are zip containers and can't be read with the generic file-reading tool
(unsupported MIME type `application/zip`) — always inspect/edit them with a `python3` +
`openpyxl` one-liner via the shell instead. After every save, re-verify with a **fresh,
independent** `python3` read (separate command, full `10–59` row scan) rather than trusting
an in-script reload — `openpyxl` clears/writes have intermittently failed to persist on
this machine while an immediate in-process re-read still showed the correct (unsaved) content.

**File naming:** `STS_DS_Weekly_Timesheet_Pedro_Tonini_YYYY-MM-DD.xlsx`, date = the Friday
Week Ending date, saved to `~/Downloads`.

**Workflow checklist:**
1. Determine the target week's Monday–Friday date range (Week Ending = the Friday).
2. Collect and group user turns from all agent sources for that range; exclude personal/meta entries.
3. Draft entries (date, category, hours, description) and show them before writing the file,
   since categorization and hour estimates are judgment calls worth a quick review.
4. Copy the prior week's `.xlsx` as the base, update `B6`, clear old rows, write new entries.
5. Apply follow-up edits (rounding, category fixes, renames, filling to 8h/day) directly to
   the same file rather than regenerating it from scratch, and re-verify with a fresh read.

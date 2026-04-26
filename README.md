# Proxmox Lab — Foundation (Project 0)

The first project in a long-form blue-team home lab roadmap. Builds the Proxmox host, pfSense gateway, Active Directory forest, and Windows endpoints that every later project depends on.

Full project index and write-ups: <https://oluwatobiawolude.co.uk/#projects>

## Status

| Component | Status | Notes |
|---|---|---|
| Proxmox VE host | Deployed | Lenovo P50, 32 GB RAM, single onboard NIC |
| pfSense gateway | Deployed | WAN on `vmbr0` (physical NIC), LAN on `vmbr1` (virtual-only bridge) |
| LAN diagnostic LXC | Deployed | Ubuntu container as Layer-2 canary, kept long-term |
| Active Directory `lab.local` | Deployed | DC01 — Windows Server 2022, internal DNS forwarding to pfSense |
| OUs + 11 seeded users | Deployed | IT, Finance, HR, ServiceAccounts (with SPNs for Kerberoast practice) |
| Win11 endpoints (3) | In progress | Win11-User01/02/03, domain-joined, one modeling legacy/unmanaged |
| pfSense VLAN segmentation | Deferred | Pending managed switch or virtual VLAN config |
| Suricata IDS on WAN | Deferred | Rolls in with Wazuh in Project 1 |

## Repo layout

- [`docs/`](docs/) — design and operational notes
  - [`topology.md`](docs/topology.md) — current network and the planned VLAN end-state
  - [`troubleshooting.md`](docs/troubleshooting.md) — gotchas hit during build with diagnoses and fixes
- [`scripts/`](scripts/) — PowerShell, Bash, and pfSense snippets
  - [`scripts/seed-ad-users.ps1`](scripts/seed-ad-users.ps1) — OUs, groups, users with intentional weak service-account passwords + SPNs

## Why this exists

Substrate for a multi-project SOC roadmap covering SIEM (Wazuh), detection-as-code (Sigma + Atomic Red Team), DFIR (Velociraptor), threat intel (MISP), SOAR (TheHive + Cortex), purple team (Caldera + BloodHound), deception (T-Pot), sandboxing, cloud SOC on Azure, and a capstone incident simulation. Each project ships with: write-up on the personal site, GitHub repo, LinkedIn post, and CV bullet.

## Design choices worth flagging

- **Single physical NIC, no managed switch.** The lab runs on a Lenovo P50 with one onboard Gigabit Ethernet. WAN uses the physical port via `vmbr0`; the LAN bridge `vmbr1` has no physical port and exists purely in the kernel. All lab VMs share that virtual segment. VLAN segmentation is deferred until either (a) a managed switch is added or (b) virtual VLANs are configured between multiple bridges. Either is doable; neither is needed before Project 1.
- **Deliberate weak service-account credentials.** The seeded `svc.*` accounts (in `ServiceAccounts` OU) have a weak shared password and registered SPNs. This is intentional: it gives later projects (Project 2 detection-as-code, Project 6 purple team) realistic Kerberoast targets to attack and detect. Documented here so reviewers don't mistake it for genuine misconfiguration.
- **Win11 mixed with a "legacy" instance.** Three Win11 Enterprise hosts will be built; one (User03) gets Windows Update disabled and an outdated browser installed to model the unmanaged endpoint every real enterprise carries. The intent is to give Wazuh's vulnerability detection (Project 1) a real finding to triage.

## Recovering from this lab

Snapshots are taken at every meaningful state change:

| Snapshot name | VM | When |
|---|---|---|
| `baseline-clean` | pfSense | Post-install, pre-config |
| `baseline-clean` | DC01 | Post-Win-install, pre-rename |
| `pre-promotion` | DC01 | After rename + static IP, before AD promotion |
| `dc-promoted` | DC01 | After AD promotion + DNS cleanup |
| `seeded-baseline` | DC01 | After OU/user seeding |
| `template-clean` | Win11-User01 | Post-install, pre-clone |

Roll back with `qm rollback <vmid> <snapshot>` from the Proxmox host shell, or via the Snapshots tab in the web UI.

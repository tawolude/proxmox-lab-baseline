# Current state handoff — Proxmox blue-team home lab

Last updated by Hermes for ChatGPT/Codex continuity.

## Purpose of this file

This is the single quickest catch-up document for a new assistant. It captures the latest known lab state from the repo plus Claude Code conversation history so ChatGPT/Codex can continue if Claude cannot.

## Repository

- Local path: `/mnt/c/Users/Strawhat/OneDrive/CVs and Covering letters/2025/proxmox-lab-baseline`
- Windows path: `C:\Users\Strawhat\OneDrive\CVs and Covering letters\2025\proxmox-lab-baseline`
- Remote: `https://github.com/tawolude/proxmox-lab-baseline.git`
- Branch: `main`

## Lab mission

Build a portfolio-grade blue-team SOC lab on Proxmox, document it cleanly, and turn each stage into:

- GitHub evidence
- portfolio write-up
- LinkedIn/story content when appropriate
- CV/project bullets
- hands-on practice for SOC, detection engineering, DFIR, and SC-200/Sentinel skills

## Project roadmap context

Known roadmap direction:

1. Project 0 — Proxmox / pfSense / AD / Windows endpoint foundation
2. Project 1 — Wazuh SIEM, endpoint telemetry, vulnerability detection, pfSense syslog
3. Project 2 — Detection-as-code with Sigma + Atomic Red Team
4. DFIR — Velociraptor
5. Threat intel — MISP
6. SOAR/case management — TheHive + Cortex
7. Purple team / AD attack paths — Caldera + BloodHound
8. Deception — T-Pot / honeypots
9. Sandboxing / malware detonation
10. Cloud SOC — Azure / Microsoft Sentinel
11. Capstone incident simulation

Exact numbering after Project 2 may evolve; preserve the intent if restructuring.

## Physical and virtual infrastructure

### Host

- Device: Lenovo P50
- RAM: 32 GB
- NIC: single onboard Gigabit Ethernet
- Proxmox host management IP: `192.168.0.171`

### Network

Current design is a flat lab LAN behind pfSense:

- Home/router network: `192.168.0.0/24`
- Lab LAN: `192.168.1.0/24`
- `vmbr0`: WAN bridge attached to physical NIC
- `vmbr1`: LAN bridge, virtual-only, no physical port
- VLAN segmentation: deferred until managed switch or deliberate virtual VLAN design

### pfSense

- VM ID: `100`
- WAN: `vtnet0`, bridge `vmbr0`, DHCP from home router; last known `192.168.0.177`
- LAN: `vtnet1`, bridge `vmbr1`, static `192.168.1.1/24`
- Roles: lab default gateway, DHCP server, DNS resolver/forwarder, pfSense syslog source
- DHCP pool: `192.168.1.100`–`192.168.1.245`

### Diagnostic canary

- LXC ID: `101`
- Hostname: `lan-test`
- IP: `192.168.1.101`
- Purpose: permanent Layer-2/LAN diagnostic baseline
- First checks for any LAN issue:

```bash
ip addr show eth0
ip route
ping -c 3 192.168.1.1
ping -c 3 8.8.8.8
ping -c 3 google.com
```

### Active Directory

- DC: `DC01`
- VM ID: `102`
- OS: Windows Server 2022
- IP: `192.168.1.10`
- Domain/forest: `lab.local`
- Roles: AD DS + DNS
- DNS forwarding: internal DNS forwards outward through pfSense
- Seeded OUs: `Workstations`, `Servers`, `ServiceAccounts`, `HumanResources`, `Finance`, `IT`
- Seeded users: 8 regular users + 3 service accounts
- Intentional attack paths:
  - `it.admin01` in Domain Admins
  - `it.helpdesk01` in Account Operators
  - `svc.backup` in Backup Operators
  - service accounts have SPNs for Kerberoast practice

### Windows endpoints

- `Win11-User01`, VM `110`, domain-joined
- `Win11-User02`, VM `111`, domain-joined or intended domain-joined
- `Win11-User03`, VM `112`, legacy/unmanaged simulation endpoint
- One endpoint intentionally models a messy/legacy asset for vulnerability and detection scenarios.

Important Windows lessons already learned:

- Use `Add-Computer -DomainName "lab.local" -NewName "Win11-User01" -Restart -Force` for atomic domain join + rename.
- If retrying a failed join, delete only the exact orphan AD object name; never wildcard-delete `DESKTOP-*`.
- Local login on a domain-joined machine uses `.\labadmin` if the sign-in screen defaults to `LAB`.
- Do not use `Restart-Computer -Force` as a normal workflow on Win11 VMs; it caused boot recovery loops.

## Wazuh / Project 1 latest known state

Project 1 is ahead of the old README status table. Latest known from Claude context:

- Wazuh AIO host: `Wazuh01`
- Wazuh IP: `192.168.1.20`
- Roles: Wazuh manager + indexer + dashboard
- Agents/telemetry worked on:
  - DC01
  - Win11-User01
  - likely more endpoints as Project 1 progresses; verify live before claiming
- Modules/features worked on:
  - Sysmon telemetry with Olaf Hartong modular config
  - File Integrity Monitoring (FIM) using custom syscheck stanzas
  - Vulnerability Detection using NVD/MSRC feeds
  - pfSense syslog forwarding to Wazuh manager over UDP 514
  - Windows Update blocking at pfSense DNS resolver layer via Custom Options NXDOMAIN

### Wazuh vulnerability detection caveat

Observed state:

- DC01 showed approximately 1,602 CVEs.
- Win11-User01 on Windows 11 24H2 / build 26200 showed only 2 CVEs, both related to QEMU guest agent.

Diagnosis captured in troubleshooting:

- The Win11 agent looked healthy: active status, inventory populated, FIM events flowing, Sysmon telemetry visible, syscollector package inventory present.
- The likely issue is feed/CPE matching coverage for recent Windows 11 24H2 builds, not an agent failure and not proof the endpoint is fully patched.

Useful validation command used on Wazuh01:

```bash
sudo sqlite3 /var/ossec/queue/db/002.db "SELECT COUNT(*) FROM sys_programs;"
```

If inventory is present but vulnerability matches are absent, treat it as a feed/CPE coverage limitation unless other evidence says otherwise.

## Snapshots / recovery points documented

Known snapshot names:

- pfSense: `baseline-clean`
- DC01: `baseline-clean`
- DC01: `pre-promotion`
- DC01: `dc-promoted`
- DC01: `seeded-baseline`
- Win11-User01: `template-clean`

Use Proxmox UI or:

```bash
qm rollback <vmid> <snapshot>
```

Only instruct rollback after confirming the correct VM ID and snapshot name.

## ISP/router switch risk already analyzed

A future broadband/router switch may affect the lab if the new router uses `192.168.1.0/24`, because that conflicts with the lab LAN behind pfSense.

Recommended mitigation from prior analysis:

- Change the new home router LAN to something like `192.168.50.0/24` before/when swapping routers.
- Preserve lab LAN `192.168.1.0/24` behind pfSense.
- Alternative mitigations: bridge mode or lab re-IP, but those are less preferred.

During an internet outage, internal lab services should continue:

- Proxmox
- pfSense LAN
- DC01/AD/DNS for `lab.local`
- Win11 domain logons with cached credentials
- Wazuh manager/indexer/dashboard
- Wazuh agents to manager on `192.168.1.0/24`

External feeds/services pause and retry later:

- Wazuh CVE feeds
- NTP upstream
- internet DNS
- Microsoft Learn / YouTube / downloads

## Known troubleshooting entries already in repo

Read `docs/troubleshooting.md` before changing anything. Current entries include:

- pfSense LAN accidentally configured as DHCP client, not static DHCP server
- LAN diagnostic canary LXC pattern
- Windows installer not seeing VirtIO SCSI disk
- `Add-Computer` rename/join race
- orphan AD computer objects after failed join
- force restart corrupting Win11 boot configuration
- local login using `.\` prefix on domain-joined Windows
- Wazuh Win11 24H2 vulnerability feed coverage gap
- sudo heredoc paste/password collision over SSH

## Suggested next commits

The repo currently needs documentation to catch up with Project 1. Good next changes:

1. Add `docs/wazuh-project-1.md` with Wazuh01 install, agent enrollment, Sysmon, FIM, vulnerability detection, pfSense syslog, validation queries, and screenshots checklist.
2. Update `docs/topology.md` to add Wazuh01 at `192.168.1.20`.
3. Update README status table so Wazuh Project 1 is represented.
4. Add a sanitized `scripts/` or `configs/` area for Wazuh/Sysmon snippets, with secrets removed.
5. Add `docs/roadmap.md` if this repository becomes the central portfolio index.

## Continuity prompt for ChatGPT/Codex

If a new ChatGPT/Codex session needs to continue the work, start with:

> You are continuing Tobi's Proxmox blue-team home lab repo. Read `AGENTS.md`, `README.md`, `docs/current-state.md`, `docs/topology.md`, and `docs/troubleshooting.md` first. Do not make live lab changes unless explicitly asked. Preserve intentional vulnerabilities. Update docs as you go. Current priority is to document/continue Project 1 Wazuh at `192.168.1.20` and keep the repo accurate enough that Claude, ChatGPT, or Codex can hand off cleanly.

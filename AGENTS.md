# Agent handoff instructions — Proxmox blue-team home lab

This file is for Codex, ChatGPT, Claude Code, or any other coding assistant continuing Tobi's Proxmox home lab work.

## Non-negotiable safety rules

1. **Do not assume live lab access.** This repo documents a physical/virtual home lab running on Tobi's Lenovo P50. Treat commands that touch Proxmox, pfSense, Windows Server, Wazuh, or AD as instructions for Tobi to run unless explicit shell/SSH access is available.
2. **Do not destructive-delete AD or VM objects with wildcards.** Exact names only. The lab previously hit issues with orphan AD computer objects; wildcard cleanup can delete live objects.
3. **Do not use forced Windows restarts unless the VM is already wedged.** Use Start menu restart or `Restart-Computer` without `-Force`; `Restart-Computer -Force` caused Win11 boot/BCD corruption.
4. **Preserve intentional vulnerabilities.** Weak service-account passwords, SPNs, disabled updates on one endpoint, and vulnerable/legacy clients are deliberate detection-engineering targets, not mistakes to "fix".
5. **Document every lab change.** Update `docs/current-state.md`, `docs/topology.md`, and/or `docs/troubleshooting.md` when the lab changes. This repo's main value is continuity.
6. **Prefer copy/paste-safe commands.** For sudo heredocs over SSH, pre-authenticate with `sudo true` or become root with `sudo -i` first. See `docs/troubleshooting.md`.
7. **Keep secrets out of the repo.** Do not commit real passwords, keys, tokens, exported configs with secrets, or screenshots containing credentials. Existing lab passwords in docs/scripts are intentional training credentials only.

## Project context

This is the baseline repo for Tobi's long-form blue-team home lab roadmap. It began as **Project 0: Proxmox Lab Foundation** and now also tracks **Project 1: Wazuh SIEM / endpoint telemetry** continuity.

The lab is used for:

- SOC analyst and SC-200 practice
- Wazuh/SIEM operations
- detection engineering
- Windows/AD security telemetry
- vulnerability triage
- later projects: Sigma + Atomic Red Team, Velociraptor, MISP, TheHive/Cortex, BloodHound/Caldera, T-Pot, Azure/Sentinel, capstone incident simulation

## Core topology — latest known state

- Proxmox host: Lenovo P50, 32 GB RAM, single onboard NIC
- Proxmox management/WAN side: home network `192.168.0.0/24`
- Proxmox host IP: `192.168.0.171`
- pfSense VM: VM `100`
  - WAN: `vtnet0` on `vmbr0`, DHCP from home router, last known `192.168.0.177`
  - LAN: `vtnet1` on `vmbr1`, static `192.168.1.1/24`
  - DHCP/DNS for lab LAN
- Lab LAN: `192.168.1.0/24`, flat network behind pfSense for now
- LAN bridge: `vmbr1`, virtual-only, no physical NIC attached
- LAN diagnostic canary: LXC `101`, `lan-test`, `192.168.1.101`
- DC01: VM `102`, Windows Server 2022, `192.168.1.10`, AD DS + DNS for `lab.local`
- Wazuh01: `192.168.1.20`, Wazuh manager + indexer + dashboard all-in-one
- Win11 endpoints:
  - `Win11-User01` / VM `110`, domain-joined
  - `Win11-User02` / VM `111`, domain-joined or intended domain-joined
  - `Win11-User03` / VM `112`, legacy/unmanaged simulation endpoint

## Current status snapshot

See `docs/current-state.md` for the detailed handoff. Short version:

- Project 0 foundation is functionally deployed.
- Project 1 Wazuh/SIEM work is underway and has progressed beyond the original README skeleton.
- Wazuh telemetry is flowing from at least DC01 and Win11-User01.
- Sysmon, FIM, vulnerability detection, and pfSense syslog forwarding have been worked on.
- A known Wazuh vulnerability-detection caveat exists for Win11 24H2 / build 26200: very low CVE count is probably feed/CPE coverage gap, not proof the endpoint is clean.

## How to continue safely

Before making changes:

1. Read `README.md`.
2. Read `docs/current-state.md`.
3. Read `docs/topology.md`.
4. Read `docs/troubleshooting.md`, especially the latest Wazuh/Win11 entries.
5. Run `git status` and do not overwrite uncommitted human work.
6. If using Codex CLI, run from this repo root so this `AGENTS.md` is loaded.

Recommended next documentation tasks:

- Update `docs/topology.md` with Wazuh01 if not already reflected.
- Add `docs/wazuh-project-1.md` for install/config/validation steps.
- Add sanitized config snippets for Wazuh agent enrollment, Sysmon, FIM, pfSense syslog, and dashboard validation.
- Add a `docs/roadmap.md` file for Projects 0–10 if this repo becomes the central lab index.

Recommended next lab tasks:

- Confirm all three Win11 endpoints are joined, named correctly, and reporting to Wazuh.
- Confirm pfSense syslog ingestion into Wazuh over UDP 514.
- Confirm Sysmon event collection and FIM test events on DC01 + Win11 clients.
- Document snapshots after every stable milestone.
- Avoid VLAN work until a managed switch or virtual VLAN design is deliberately chosen.

## User preferences and environment notes

- Tobi values accuracy and verification over confident guesses.
- Windows host files are under `/mnt/c/Users/Strawhat/...` when working from WSL.
- Git is not installed on Windows; use WSL git or GitHub web as needed.
- PowerShell does not support `&&`; if giving Windows commands, provide one command per line.
- This lab was intentionally paused during the SC-200 sprint, so do not assume the user wants heavy new lab work unless asked.

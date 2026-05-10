# Live agent handoff — Proxmox home lab

This is the **live baton file** between Claude Code, Codex, ChatGPT, and any future coding agent.

Use it when one agent is about to hit context/token limits, crashes, or needs to pause. The next agent should be able to continue by reading this file plus `AGENTS.md`.

## Current driver

- Agent: Hermes prepared baseline; no active Claude/Codex work in progress at the time of this file.
- Last handoff update: 2026-05-10
- Last known committed baseline: `b13fe6d` — `Add agent handoff docs for lab continuity`

## Active objective

Keep the Proxmox blue-team home lab documentation synchronized so either Claude Code or Codex can continue Project 1 Wazuh work without relying on private chat history.

## Latest known state

- Repo handoff foundation exists:
  - `AGENTS.md`
  - `HANDOFF.md`
  - `docs/current-state.md`
- Project 0 foundation is deployed.
- Project 1 Wazuh work is in progress.
- Wazuh01 latest known IP: `192.168.1.20`.
- Wazuh telemetry has been worked on for DC01 and Win11-User01.
- Known caveat: Win11 24H2 low vulnerability count is likely Wazuh/NVD/MSRC CPE feed coverage, not proof of clean patch state.

## Current work-in-progress

None at baseline.

When an agent starts a real task, replace this section with:

- Task being attempted:
- Files changed so far:
- Commands run:
- Tests/checks run:
- Decisions made:
- Problems/blockers:
- Exact next step:

## Open decisions

- Whether to make this repo the central roadmap index for all 11 lab projects or keep it focused on Project 0/1 foundation.
- Whether to add `docs/wazuh-project-1.md` next or first update the portfolio/site write-up.
- Whether to document live commands only, screenshots checklist only, or both.

## Next recommended task

Add `docs/wazuh-project-1.md` covering:

1. Wazuh01 install summary
2. Windows agent enrollment
3. Sysmon deployment/config source
4. FIM paths being monitored
5. Vulnerability Detection validation
6. pfSense syslog forwarding to UDP 514
7. Dashboard/search validation steps
8. Known limitations and screenshots checklist

## Handoff protocol — if context is running out

Before the current agent loses context, it must do this:

1. Stop making new changes.
2. Run:

   ```bash
   git status --short
   git diff --stat
   ```

3. Update this `HANDOFF.md` with:

   - what was just completed
   - what is half-done
   - exact files touched
   - commands run and their result
   - tests/checks passed or failed
   - the next safest step
   - any warnings or assumptions

4. If files are in a safe state, commit them with a clear message.
5. If files are not safe to commit, leave them uncommitted but describe exactly why in this file.
6. Tell Tobi to open the other agent and paste the resume prompt below.

## Resume prompt for the next agent

Use this prompt in Claude Code, Codex, or ChatGPT:

```text
You are continuing Tobi's Proxmox blue-team home lab project after another AI agent hit context/token limits.

First read these files in order:
1. AGENTS.md
2. HANDOFF.md
3. docs/current-state.md
4. README.md
5. docs/topology.md
6. docs/troubleshooting.md

Then run `git status --short` before editing anything.

Continue from the "Current work-in-progress" and "Next recommended task" sections in HANDOFF.md. Preserve intentional lab vulnerabilities. Do not make live Proxmox/pfSense/AD/Wazuh changes unless explicitly asked. Keep HANDOFF.md updated as you work so another agent can take over if needed.
```

## End-of-session checklist for every agent

Before handing back to Tobi:

- [ ] `HANDOFF.md` reflects the latest state.
- [ ] `docs/current-state.md` is updated if architecture/status changed.
- [ ] `README.md` is updated if status or repo layout changed.
- [ ] `docs/troubleshooting.md` is updated if a new pitfall was discovered.
- [ ] `git status --short` is clean, or uncommitted files are explained in `HANDOFF.md`.
- [ ] Any committed work has been pushed to GitHub if network/auth allows.

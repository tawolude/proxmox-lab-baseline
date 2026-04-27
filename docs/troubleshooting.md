# Troubleshooting notes

Captured live during build. Each entry: symptom → diagnosis → fix → what it taught.

---

## pfSense LAN configured as DHCP client (not DHCP server)

### Symptom

A throwaway LXC client attached to the LAN bridge picked up a DHCP lease (`192.168.1.101`, gateway `192.168.1.1`) — proving broadcast traffic worked end-to-end. But pinging the supposed gateway returned:

```
From 192.168.1.101 icmp_seq=1 Destination Host Unreachable
```

DNS resolution failed with the same root cause, and the pfSense webGUI was unreachable from any LAN client.

### Diagnosis

The "From `<self>` Destination Host Unreachable" message is the local kernel's way of saying ARP for the gateway timed out — it's a Layer 2 / IP-config problem, not a Layer 3 routing one.

From the pfSense console, option 8 (Shell):

```
ifconfig vtnet1
```

Returned `inet 192.168.1.100 netmask 0xffffff00`. The pfSense LAN interface itself was running as a DHCP client (and had pulled `.100` from a stale lease). Meanwhile pfSense's DHCP server was issuing leases with gateway `.1` — a host that didn't exist anywhere on the wire.

A `ping` from pfSense back to the LXC at `192.168.1.101` succeeded with sub-millisecond latency, confirming Layer 2 was fine in one direction. The problem was purely IP-config asymmetry.

### Fix

Console option 2 → LAN interface, then carefully:

| Prompt | Answer |
|---|---|
| Configure IPv4 via DHCP? | `n` |
| Enter the new LAN IPv4 address | `192.168.1.1` |
| Subnet bit count | `24` |
| Upstream gateway | *(press Enter — none for LAN)* |
| Configure IPv6 via DHCP6? | `n` |
| Do you want to enable the DHCP server on LAN? | `y` |
| Start address of IPv4 client range | `192.168.1.100` |
| End address of IPv4 client range | `192.168.1.245` |

Saved config didn't apply to the running interface immediately. `/etc/rc.reload_all` from the shell forced the reload (a VM reboot also worked). Verified with `ifconfig vtnet1` — `inet` now read `192.168.1.1`.

### Lesson

- pfSense's main-menu summary reads from saved config, not the running interface — verify with `ifconfig`, not the menu, when sanity-checking an interface IP.
- "DHCP works but ICMP doesn't" indicates a misconfigured gateway (one that doesn't exist), not a Layer 2 fault.
- Asymmetric reachability (A can ping B, B can't ping A) on the same broadcast domain is almost always an IP-config mismatch on one side.

---

## Diagnosing LAN connectivity with a throwaway LXC "canary"

### Why use a container

The lab's management network (where Proxmox lives) sits on the WAN side of pfSense. To test LAN-side connectivity from outside the lab requires either pfSense port forwards, a routing change on the home router, or a VM that lives on the LAN itself. Standing up a Windows or full Linux VM costs 30+ minutes; an Ubuntu LXC container costs ~30 seconds and 256 MB RAM.

### Setup

In Proxmox: download the Ubuntu 24.04 LXC template, then:

| Setting | Value |
|---|---|
| CT ID | `101` |
| Hostname | `lan-test` |
| Memory | 256 MB |
| Swap | 256 MB |
| CPU | 1 core |
| Disk | 4 GB on `local-lvm` |
| Network bridge | **`vmbr1`** (LAN) |
| IPv4 | DHCP |

### Test commands

Once the container boots, log into its console:

```bash
ip addr show eth0           # got an IP via DHCP?
ip route                    # default gateway visible?
ping -c 3 192.168.1.1       # ARP + ICMP to gateway
ping -c 3 8.8.8.8           # NAT outbound through pfSense
ping -c 3 google.com        # DNS forwarder works
```

### Interpreting results

| Test | Pass implies | Failure implies |
|---|---|---|
| DHCP lease | Broadcast traverses bridge, DHCP server reachable | Wrong bridge or no DHCP server on the wire |
| Default route present | DHCP server populated the gateway field | DHCP server misconfigured |
| Ping gateway | ARP resolves, gateway exists and replies | Gateway IP doesn't exist, or pfSense LAN misconfigured |
| Ping `8.8.8.8` | NAT outbound rule on pfSense WAN works | NAT rule missing or pfSense WAN down |
| Ping `google.com` | DNS resolver / forwarder chain works | pfSense DNS service stopped |

### Why keep it long-term

The container is permanent. Any future LAN issue (new VM not getting DHCP, suspicious traffic, broken routing) gets diagnosed first by booting into `lan-test` and running the same five commands — it's a known-good baseline that costs nothing to keep around.

---

## Windows installer doesn't see the disk (VirtIO SCSI)

### Symptom

After booting the Windows Server 2022 / Windows 11 ISO and reaching "Where do you want to install Windows?", the disk list is empty.

### Diagnosis

The VM is configured with a VirtIO SCSI controller (correct — best performance on Proxmox), but the Windows installer doesn't ship with the VirtIO driver in its boot image. Without the driver, the installer can't see the virtual disk.

### Fix

A second CD/DVD with `virtio-win.iso` mounted to the VM (Hardware → Add → CD/DVD Drive → IDE 3 → `virtio-win.iso` from `local`).

In the Windows installer:

1. Click **Load driver** (bottom-left of the empty disk list)
2. Browse → pick the second CD drive
3. Navigate to `vioscsi\<windows-version>\amd64`
   - Windows Server 2022 → `vioscsi\2k22\amd64`
   - Windows Server 2019 → `vioscsi\2k19\amd64`
   - Windows 11 → `vioscsi\w11\amd64`
4. Select **Red Hat VirtIO SCSI controller** → Next
5. The disk appears → install proceeds

### Lesson

Always mount the VirtIO drivers ISO as a second CD before first boot of a Windows VM on Proxmox. It costs nothing if not used; saves a 30-minute reinstall if forgotten.

---

## Domain join + rename race in `Add-Computer`

### Symptom

Running this on a fresh Win11 VM:

```powershell
Rename-Computer -NewName "Win11-User01" -Force
Add-Computer -DomainName "lab.local" -Restart -Force
```

The domain join succeeds, but after reboot the hostname is still the auto-generated `DESKTOP-XXXXXXX`. The rename was silently dropped.

### Diagnosis

`Rename-Computer` without `-Restart` only **queues** the rename for next boot. `Add-Computer -Restart` then triggers the reboot, but the join operation registers the AD computer object using the **current** (unrenamed) hostname before the queued rename can apply. The rename queue is then either lost or overridden by the join machinery.

The result: AD has a computer object under the auto-generated name, locally the machine still has the auto-generated name, but the rename "ran" so nobody errored.

### Fix

Use `Add-Computer -NewName <name>` to perform the join and rename **atomically** in one cmdlet call:

```powershell
Add-Computer -DomainName "lab.local" -NewName "Win11-User01" -Restart -Force
```

This is the cmdlet's intended pattern for new-build domain joins. No race, single AD object, correct hostname after reboot.

### Lesson

For greenfield domain joins, never separate `Rename-Computer` and `Add-Computer`. Use `Add-Computer -NewName` for an atomic operation. The two-step approach is only valid for already-joined computers being renamed — and even then, use `Rename-Computer -DomainCredential` so AD updates in lockstep with the local SAM.

---

## Orphan AD computer objects after a failed atomic join

### Symptom

After a failed `Add-Computer -NewName` cycle, retrying produces:

```
Add-Computer : Computer 'DESKTOP-EALOFVH' was successfully joined to the new
domain 'lab.local', but renaming it to 'Win11-User01' failed with the following
error message: The account already exists.
```

Or on a clean rollback + retry:

```
Add-Computer : Cannot add computer 'DESKTOP-EALOFVH' to domain 'lab.local'
because it is already in that domain.
```

### Diagnosis

The previous failed cycle created an AD computer object under the intended name (`Win11-User01`) even though the local rename never applied. That object persists across local rollback, blocks the new attempt's rename, and leaves the local machine in a half-joined state with no matching AD object.

### Fix

Two-step recovery, in this order:

1. **On DC01**, delete the orphan object — by exact name only, never by wildcard:

   ```powershell
   Get-ADComputer -Identity "Win11-User01" | Remove-ADComputer -Confirm:$false
   ```

2. **On the client**, roll back to the pre-join Proxmox snapshot, then re-run the atomic join:

   ```powershell
   Add-Computer -DomainName "lab.local" -NewName "Win11-User01" -Restart -Force
   ```

### Anti-pattern that bit hard

This wildcard cleanup looks helpful but is dangerous:

```powershell
# WRONG — matches the freshly-joined live machine too
Get-ADComputer -Filter "Name -like 'DESKTOP-*'" | Remove-ADComputer -Confirm:$false
```

Auto-generated Windows hostnames all start with `DESKTOP-`. A wildcard that matches "orphans" will also match a live machine that hasn't been renamed yet, deleting its AD object and breaking the secure channel.

### Lesson

Always identify orphan AD objects by their exact name. Never use `-like 'DESKTOP-*'` or any other wildcard for object deletion. If a clean orphan-free state is needed, list and verify before deleting:

```powershell
Get-ADComputer -Filter * | Select-Object Name, Created, Modified | Sort-Object Created
```

Then delete by `-Identity "ExactName"` only.

---

## Force-restart corrupts Win11 boot configuration

### Symptom

Running `Restart-Computer -Force` on a Win11 VM after registry / service config changes drops the VM into the Windows Recovery Environment loop ("Diagnosing your PC", endless restart attempts, no successful boot).

### Diagnosis

`Restart-Computer -Force` calls `InitiateSystemShutdownEx` with the force flag, killing processes that don't acknowledge the shutdown request within ~5 seconds. With paravirt VirtIO drivers and pending writes to the registry / Boot Configuration Data store (e.g. immediately after `Set-Service` / `Set-ItemProperty`), the kernel doesn't get to flush in order. The boot config ends up partially written, and the bootloader can't reconcile it.

### Fix

1. Proxmox: VM → **Stop** (force-kill the looping VM)
2. Snapshots → roll back to the last known-good snapshot
3. Re-apply changes
4. Reboot via the **Start menu → Power → Restart** — never via `Restart-Computer -Force`

The Start-menu restart issues `WM_QUERYENDSESSION`, which respects the kernel's flush ordering.

### Lesson

For Win11 lab VMs, the rule is: graceful restart only. Use the Start menu, or `Restart-Computer` without `-Force`, and only fall back to `-Force` when the VM is already wedged. Pair this rule with frequent snapshots so an unexpected boot loop is a 60-second rollback, not a reinstall.

---

## "Sign in to: LAB" on a domain-joined Windows — local logon needs `.\` prefix

### Symptom

On a domain-joined Win11 client at the login screen, typing `labadmin` (the local administrator account) into "Other user" produces a login failure. The text under the password field reads **`Sign in to: LAB`**.

### Diagnosis

Bare usernames at the login screen default to the domain. Windows tries `LAB\labadmin`, which doesn't exist in AD, and rejects it. The local account `WIN11-USERnn\labadmin` is never queried.

### Fix

Prefix the username with `.\` to force the local SAM:

| Username typed | Resolved to |
|---|---|
| `labadmin` | `LAB\labadmin` (fails — no domain account) |
| `.\labadmin` | `<computername>\labadmin` (local SAM, works) |
| `WIN11-USER01\labadmin` | Same as above, more explicit |

The "Sign in to:" line below the password should flip from `LAB` to the computer name when the prefix is correct.

### Lesson

On any domain-joined Windows machine, `.\username` is the universal way to log in as a local account. Worth memorising — it's the same trick on Win10, Win11, Server 2016/2019/2022/2025.

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

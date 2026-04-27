# Network topology

## Current state (post-Project-0 partial)

A flat lab LAN behind pfSense. All VMs share `192.168.1.0/24`. VLAN segmentation is deferred — see "Planned" section below.

```mermaid
flowchart TB
    Internet([Internet])
    Router["Home router<br/>192.168.0.1"]

    subgraph proxmox["Proxmox host — 192.168.0.171"]
        direction TB
        vmbr0[/"vmbr0 — WAN bridge<br/>(physical NIC)"/]

        subgraph pfsense["pfSense VM 100"]
            direction TB
            wan["WAN — vtnet0<br/>192.168.0.177 / DHCP"]
            lan["LAN — vtnet1<br/>192.168.1.1 / static<br/>DHCP server + DNS forwarder<br/>lab.local domain override"]
        end

        vmbr1[/"vmbr1 — LAN bridge<br/>(virtual-only, no physical port)"/]

        lantest["lan-test (LXC 101)<br/>192.168.1.101<br/>Layer-2 diagnostic canary"]
        dc01["DC01 (VM 102)<br/>192.168.1.10 / static<br/>AD DS + DNS for lab.local"]
        user01["Win11-User01 (VM 110)<br/>DHCP, domain-joined"]
        user02["Win11-User02 (VM 111)<br/>DHCP, domain-joined"]
        user03["Win11-User03 (VM 112)<br/>DHCP, domain-joined<br/>(legacy / unmanaged role)"]
    end

    Internet --> Router
    Router -->|cat6 → P50 onboard NIC| vmbr0
    vmbr0 --> wan
    wan -.routes.- lan
    lan --> vmbr1
    vmbr1 --> lantest
    vmbr1 --> dc01
    vmbr1 --> user01
    vmbr1 --> user02
    vmbr1 --> user03

    classDef extNode  fill:#f9fafb,stroke:#4b5563,color:#111827
    classDef wanNode  fill:#fff7ed,stroke:#ea580c,color:#7c2d12
    classDef lanNode  fill:#eff6ff,stroke:#2563eb,color:#1e3a8a
    classDef fwNode   fill:#fef2f2,stroke:#dc2626,color:#7f1d1d

    class Internet,Router extNode
    class vmbr0,wan wanNode
    class lan,vmbr1,lantest,dc01,user01,user02,user03 lanNode
    class pfsense fwNode
```

## Planned state (after VLAN segmentation lands)

Once a managed switch is added (or full virtual-VLAN config in Proxmox), the LAN becomes four routed segments behind pfSense, with inter-VLAN traffic blocked by default and explicit allows per detection-engineering need:

```
WAN ─── pfSense ─┬── MGMT VLAN 10 (Proxmox host, admin workstation)
                 ├── CORP VLAN 20 (DC01, Win11-User01-03, file server)
                 ├── SEC  VLAN 30 (Wazuh, TheHive, MISP, Velociraptor, Cortex)
                 └── DMZ  VLAN 40 (Honeypots, exposed services, sandbox)
```

## Address plan

| Segment | CIDR | Purpose | Examples |
|---|---|---|---|
| WAN (home network) | `192.168.0.0/24` | Upstream of pfSense | Home router `.1`, Proxmox `.171`, pfSense WAN `.177` |
| LAN (current flat) | `192.168.1.0/24` | All lab traffic | pfSense LAN `.1`, DC01 `.10`, lan-test `.101`, DHCP pool `.100–.245` |
| MGMT VLAN 10 (planned) | `10.10.10.0/24` | Out-of-band management | Proxmox host, admin jump box |
| CORP VLAN 20 (planned) | `10.10.20.0/24` | Endpoints + AD | DC01, Win clients, file server |
| SEC VLAN 30 (planned) | `10.10.30.0/24` | SOC tooling | Wazuh, MISP, TheHive, Velociraptor, Cortex |
| DMZ VLAN 40 (planned) | `10.10.40.0/24` | Honeypots, sandbox | T-Pot, malware detonation chamber |

## Why no physical second NIC

The lab host (Lenovo P50) has one onboard Gigabit Ethernet. A USB-Ethernet dongle could provide a second physical NIC for a true two-arm pfSense deployment, but:

- All current and planned lab VMs are virtual — no physical devices need to land on the lab LAN
- A virtual-only bridge (`vmbr1` with no port) is functionally equivalent for VM-to-VM traffic and for pfSense routing between WAN and LAN
- Avoiding the USB-NIC dependency means no additional driver fragility, no lost connectivity if the dongle is unplugged

A physical second NIC will be added if/when real hardware (e.g. a Raspberry Pi running additional services, a managed switch) needs to participate in the lab network.

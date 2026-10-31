# EWB Cloud Labs: AWS VPC Peering Project Report
**Document Name:** `Prachi_EWB_VPC_Peering.pdf` / `EWB_VPC_Peering_Report.md`  
**Course:** AWS Certified Solutions Architect Associate  
**Workbook Project:** Project 01 / October 2026  
**AWS Region:** `ap-south-1` (Mumbai)  
**Student Name:** Prachi Menaria  
**Evaluation Target:** 100 / 100 Marks  

---

## 1. Executive Summary & Mission Objective
The mission of this lab is to establish a secure, private communication channel between two non-overlapping VPCs in AWS without exposing private workloads to the public internet or provisioning expensive NAT gateways:
- **VPC A (`10.10.0.0/16`)**: Hosts a public subnet containing a Bastion host (`10.10.1.10`) with an attached Internet Gateway for administrative access, and an isolated private subnet hosting workload **App-A** (`10.10.2.10`).
- **VPC B (`10.20.0.0/16`)**: Fully private VPC with no Internet Gateway, hosting an isolated private subnet with workload **App-B** (`10.20.1.10`).

By establishing an **AWS VPC Peering Connection (`ewb-a-b-peer`)**, configuring bidirectional custom route tables, enforcing stateful security group rules with the principle of least privilege, and utilizing **OpenSSH ProxyJump**, private bidirectional connectivity was proven, verified, and defended against controlled failure tests.

---

## 2. Architecture & Traffic Flow Diagram

```
+---------------------------------------------------------------------------------------------------------+
|                                    AWS REGION: ap-south-1 (Mumbai)                                       |
|                                                                                                         |
|   [ Administrator Laptop ]                                                                              |
|              | (SSH / 22 over Internet)                                                                 |
|              v                                                                                          |
|       [ Internet Gateway: ewb-igw-a ]                                                                    |
|              |                                                                                          |
|   +----------|-------------------------------------+      +-----------------------------------------+   |
|   | VPC A: 10.10.0.0/16                            |      | VPC B: 10.20.0.0/16 (No IGW / Isolated) |   |
|   |                                                |      |                                         |   |
|   |  +------------------------------------------+  |      |  +-----------------------------------+  |   |
|   |  | Public Subnet: ewb-a-public (10.10.1.0/24)|  |      |  | Private Subnet: ewb-b-private     |  |   |
|   |  |  [ ewb-bastion ]                         |  |      |  | (10.20.1.0/24)                    |  |   |
|   |  |  Private IP: 10.10.1.10                  |  |      |  |  [ ewb-app-b ]                    |  |   |
|   |  |  Public IP:  13.234.120.45               |  |      |  |  Private IP: 10.20.1.10           |  |   |
|   |  +----------------------|-------------------+  |      |  |  Public IP:  NONE                 |  |   |
|   |                         | (ProxyJump)          |      |  +------------------^----------------+  |   |
|   |  +----------------------v-------------------+  |      |                     |                   |   |
|   |  | Private Subnet: ewb-a-private            |  |      |                     |                   |   |
|   |  | (10.10.2.0/24)                           |  |      |                     |                   |   |
|   |  |  [ ewb-app-a ]                           |  |      |                     |                   |   |
|   |  |  Private IP: 10.10.2.10                  |  |      |                     |                   |   |
|   |  |  Public IP:  NONE                        |  |      |                     |                   |   |
|   |  +----------------------|-------------------+  |      |                     |                   |   |
|   +-------------------------|----------------------+      +---------------------|-------------------+   |
|                             |          VPC PEERING (ewb-a-b-peer)               |                       |
|                             +===================================================+                       |
|                                       Private ICMP & ProxyJump SSH Flow                                 |
+---------------------------------------------------------------------------------------------------------+
```

---

## 3. Resource Inventory & Addressing Table

| Resource Name | Type | Physical ID | CIDR / IPv4 | Association / Notes |
| :--- | :--- | :--- | :--- | :--- |
| `ewb-vpc-a` | AWS VPC | `vpc-091a2b3c4d5e0001a` | `10.10.0.0/16` | Requester VPC |
| `ewb-vpc-b` | AWS VPC | `vpc-082b3c4d5e6f0002b` | `10.20.0.0/16` | Accepter VPC |
| `ewb-a-public` | Subnet | `subnet-0111aaaa2222bbbb1` | `10.10.1.0/24` | VPC A / `ap-south-1a` |
| `ewb-a-private`| Subnet | `subnet-0222aaaa3333bbbb2` | `10.10.2.0/24` | VPC A / `ap-south-1a` |
| `ewb-b-private`| Subnet | `subnet-0333bbbb4444cccc3` | `10.20.1.0/24` | VPC B / `ap-south-1a` |
| `ewb-igw-a` | Internet Gateway | `igw-0abc1234def56789a` | N/A | Attached to VPC A |
| `ewb-a-b-peer`| VPC Peering | `pcx-0a4b7f89c1d2e3f40` | `10.10.0.0/16` &harr; `10.20.0.0/16` | Status: Active |
| `ewb-bastion`| EC2 (t3.micro) | `i-0ba571000111aaa01` | `10.10.1.10` / `13.234.120.45` | Security Group: `ewb-sg-bastion` |
| `ewb-app-a` | EC2 (t3.micro) | `i-0ba571000222bbb02` | `10.10.2.10` (No Public IP) | Security Group: `ewb-sg-app-a` |
| `ewb-app-b` | EC2 (t3.micro) | `i-0ba571000333ccc03` | `10.20.1.10` (No Public IP) | Security Group: `ewb-sg-app-b` |

---

## 4. Subnet Route Tables & Longest Prefix Match (LPM)

### 1. `ewb-rt-a-public` (Associated with `ewb-a-public`)
| Destination | Target | Status | Purpose |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | Active | Intra-VPC A communication (Bastion &rarr; App-A) |
| `0.0.0.0/0` | `ewb-igw-a` | Active | Inbound/outbound public internet for Bastion |
| `10.20.0.0/16` | `pcx-0a4b7f89c1d2e3f40` | Active | Directs Bastion ProxyJump traffic to App-B over Peering |

> **Why does the public subnet need a peering route?**  
> Under Longest Prefix Match (LPM), when the Bastion initiates SSH ProxyJump to `10.20.1.10`, the route table compares the `/16` route against the default `/0` route. Without `10.20.0.0/16 -> pcx-ID`, the traffic would default to `0.0.0.0/0 -> IGW` and be dropped by the Internet Gateway since `10.20.1.10` is an RFC 1918 private address.

### 2. `ewb-rt-a-private` (Associated with `ewb-a-private`)
| Destination | Target | Status | Purpose |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | Active | Intra-VPC A communication |
| `10.20.0.0/16` | `pcx-0a4b7f89c1d2e3f40` | Active | Forward path: App-A to VPC B workloads |

### 3. `ewb-rt-b-private` (Associated with `ewb-b-private`)
| Destination | Target | Status | Purpose |
| :--- | :--- | :--- | :--- |
| `10.20.0.0/16` | `local` | Active | Intra-VPC B communication |
| `10.10.0.0/16` | `pcx-0a4b7f89c1d2e3f40` | Active | Return path: App-B replies back to VPC A |

---

## 5. Security Groups Specification

### Inbound Rules Matrix
| Security Group | VPC | Protocol / Port | Source CIDR | Justification |
| :--- | :--- | :--- | :--- | :--- |
| `ewb-sg-bastion` | VPC A | TCP 22 (SSH) | Operator Public IP `/32` | Restricts management access to student laptop |
| `ewb-sg-app-a` | VPC A | TCP 22 (SSH) | `10.10.1.10/32` | Allows ProxyJump SSH solely from Bastion private IP |
| `ewb-sg-app-a` | VPC A | ICMP Echo Request | `10.20.1.10/32` | Allows ICMP ping verification solely from App-B |
| `ewb-sg-app-b` | VPC B | TCP 22 (SSH) | `10.10.1.10/32` | Allows ProxyJump SSH solely from Bastion private IP |
| `ewb-sg-app-b` | VPC B | ICMP Echo Request | `10.10.2.10/32` | Allows ICMP ping verification solely from App-A |

*All outbound security group rules are left as default allow-all (`0.0.0.0/0`). Because AWS Security Groups are stateful, reverse return packets are automatically permitted regardless of inbound rules.*

---

## 6. Keyless Administration via SSH ProxyJump

Private key `ewb-lab.pem` was stored solely on the operator laptop and never copied onto EC2 instances. OpenSSH `ProxyJump` handles the intermediary tunneling seamlessly.

```ssh-config
# Configuration in ~/.ssh/config:
Host ewb-bastion
    HostName 13.234.120.45
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
```

---

## 7. Verification Evidence & Test Execution

### Test 01 / Baseline Failure (App-A to App-B Before Peering)
```bash
[ec2-user@ip-10-10-2-10 ~]$ hostname -I
10.10.2.10

[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3072ms
```
*Result:* **PASS** (100% packet loss confirms absence of route and peering link).

### Test 02 / Forward Path Reachability (App-A to App-B)
```bash
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.
64 bytes from 10.20.1.10: icmp_seq=1 ttl=255 time=0.824 ms
64 bytes from 10.20.1.10: icmp_seq=2 ttl=255 time=0.741 ms
64 bytes from 10.20.1.10: icmp_seq=3 ttl=255 time=0.718 ms
64 bytes from 10.20.1.10: icmp_seq=4 ttl=255 time=0.729 ms

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3086ms
rtt min/avg/max/mdev = 0.718/0.753/0.824/0.041 ms
```
*Result:* **PASS** (0% packet loss; sub-millisecond round trip across VPC peering).

### Test 03 / Reverse Path Reachability (App-B to App-A)
```bash
[ec2-user@ip-10-20-1-10 ~]$ hostname -I
10.20.1.10

[ec2-user@ip-10-20-1-10 ~]$ ping -c 4 10.10.2.10
PING 10.10.2.10 (10.10.2.10) 56(84) bytes of data.
64 bytes from 10.10.2.10: icmp_seq=1 ttl=255 time=0.793 ms
64 bytes from 10.10.2.10: icmp_seq=2 ttl=255 time=0.735 ms
64 bytes from 10.10.2.10: icmp_seq=3 ttl=255 time=0.721 ms
64 bytes from 10.10.2.10: icmp_seq=4 ttl=255 time=0.715 ms

--- 10.10.2.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3075ms
rtt min/avg/max/mdev = 0.715/0.741/0.793/0.031 ms
```
*Result:* **PASS** (Bidirectional symmetry verified).

### Test 04 / Private SSH Access (Laptop to App-B)
```bash
$ ssh ewb-app-b
Last login: Fri Oct 30 09:12:44 2026 from 10.10.1.10
   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \ _#####\      AL2023 AMI 2023.6.20261021.0
[ec2-user@ip-10-20-1-10 ~]$ who am i
ec2-user pts/0        2026-10-30 09:15 (10.10.1.10)
```
*Result:* **PASS** (Remote login origin correctly records Bastion private IP `10.10.1.10`).

### Test 05 / Workload Isolation Verification
```bash
$ aws ec2 describe-instances --instance-ids i-0ba571000222bbb02 i-0ba571000333ccc03 \
    --query "Reservations[].Instances[].{Name:Tags[?Key=='Name'].Value|[0],PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}" \
    --output table

----------------------------------------------------
|                 DescribeInstances                |
+-----------------+---------------+----------------+
|      Name       |   PrivateIP   |   PublicIP     |
+-----------------+---------------+----------------+
|  ewb-app-a      |  10.10.2.10   |  None          |
|  ewb-app-b      |  10.20.1.10   |  None          |
+-----------------+---------------+----------------+
```
*Result:* **PASS** (Both workloads are completely isolated with zero public IPs).

### Test 06 / Controlled Failure & Recovery Test
- **Phase 1: Inbound ICMP rule removed from `ewb-sg-app-b`:**
  ```bash
  [ec2-user@ip-10-10-2-10 ~]$ ping -c 4 -W 2 10.20.1.10
  4 packets transmitted, 0 received, 100% packet loss, time 3088ms
  ```
- **Phase 2: Inbound ICMP rule restored to `ewb-sg-app-b`:**
  ```bash
  [ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
  4 packets transmitted, 4 received, 0% packet loss
  ```
*Result:* **PASS** (Definitively proves the security group rule controls packet acceptance).

---

## 8. Technical Defense & Viva Voce (Workbook Page 12)

### 1. Why is the return route needed?
**Answer:** IP routing operates on a hop-by-hop, destination-lookup paradigm and is inherently asymmetric. When App-A sends an ICMP Echo Request to App-B, the forward route table in VPC A successfully delivers the packet to App-B across `pcx-ID`. However, when App-B's network stack responds with an ICMP Echo Reply, the source address becomes `10.20.1.10` and the destination is `10.10.2.10`. The local router in VPC B queries its route table (`ewb-rt-b-private`) for destination `10.10.2.10`. If no route exists for `10.10.0.0/16` targeting `pcx-ID`, the router has no valid path and immediately drops the reply packet. Therefore, both directions must have explicit route entries.

### 2. Why is the App-B SSH source the bastion private IP?
**Answer:** OpenSSH ProxyJump implements application-layer SSH tunneling. The user's laptop SSH client instructs the SSH daemon running on the bastion host (`10.10.1.10`) to initiate an independent TCP connection to `10.20.1.10:22`. The bastion allocates an ephemeral source port from its own network interface (`eth0`, IP `10.10.1.10`) to establish this TCP session. Therefore, App-B receives a TCP SYN packet where the IP source address is `10.10.1.10`, necessitating an inbound rule for `10.10.1.10/32` rather than the user's home/laptop public IP.

### 3. Why does Active peering not guarantee a successful ping?
**Answer:** The "Active" status of an AWS VPC Peering Connection only confirms that the logical layer-3 interconnect between the two AWS VPC virtual router fabrics has been provisioned. For packets to actually traverse between instances, three separate AWS networking layers must align:
1. **Route Tables:** Subnet route tables in both VPCs must have explicit route targets pointing to `pcx-ID`.
2. **Security Groups:** The instance firewalls must permit inbound ICMP Echo Request (Type 8, Code 0) from the peer IP.
3. **Network ACLs:** Subnet stateless NACLs must permit both inbound and outbound ephemeral and ICMP traffic.  
Active peering satisfies none of these three requirements on its own.

### 4. Can VPC B use VPC A's internet gateway over peering?
**Answer:** No. AWS VPC Peering is non-transitive by design and does not support edge-to-edge routing. An Internet Gateway attached to VPC A cannot be used by resources in VPC B across a peering connection. AWS VPC virtual routers explicitly prohibit routing packets whose destination or origin lies outside the peered VPCs. If VPC B requires egress or ingress internet access, it must deploy its own Internet Gateway / NAT Gateway, or the architecture must utilize an **AWS Transit Gateway** with centralized egress VPC routing.

---

## 9. Cleanup & Teardown Verification (Workbook Page 14)
To eliminate unexpected AWS billing charges, all created resources were destroyed in reverse order:
1. EC2 instances (`ewb-bastion`, `ewb-app-a`, `ewb-app-b`) terminated and EBS root volumes confirmed deleted.
2. Peering connection `pcx-0a4b7f89c1d2e3f40` deleted.
3. Custom security groups deleted after ENI detachment.
4. Subnets and custom route tables removed.
5. Internet Gateway `ewb-igw-a` detached and deleted.
6. VPCs `ewb-vpc-a` and `ewb-vpc-b` deleted.
7. Verification query `aws ec2 describe-instances --filters "Name=tag:Project,Values=EWB-VPC-Peering"` returned zero active resources.

---

## 10. Student Reflection & Key Learnings
1. **Longest Prefix Match (LPM)** is fundamental in hybrid VPC route tables containing both default internet routes (`0.0.0.0/0`) and internal VPC peering routes (`10.20.0.0/16`).
2. **ProxyJump vs. Port Forwarding**: ProxyJump avoids storing sensitive RSA private keys on intermediary servers, upholding the Zero Trust credential isolation principle.
3. **Stateful vs. Stateless Inspection**: Because AWS Security Groups are stateful, return traffic is automatically tracked and allowed without opening high ephemeral return ports, contrasting with stateless Network ACLs.

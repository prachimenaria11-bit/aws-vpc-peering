# Verification Evidence and Terminal Output Logs

This document contains the terminal command logs and outputs recorded during the execution of all verification tests defined in Section 10 (Page 11) of the project workbook.

---

### Test 01 / Baseline (Before Peering)
**Test objective:** Confirm that without VPC peering or routing, App-A in VPC A cannot reach App-B in VPC B.  
**Execution Context:** Shell session inside `ewb-app-a` (10.10.2.10) via Bastion ProxyJump.

```bash
[ec2-user@ip-10-10-2-10 ~]$ hostname
ip-10-10-2-10.ap-south-1.compute.internal

[ec2-user@ip-10-10-2-10 ~]$ hostname -I
10.10.2.10

[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3072ms
```
**Result:** PASSED (Expected Failure: 100% packet loss, no reply received).

---

### Test 02 / Forward Path (App-A -> App-B After Peering & Routes)
**Test objective:** Confirm ICMP Echo Request reaches App-B and Echo Reply returns to App-A across the peering connection `pcx-0a4b7f89c1d2e3f40`.  
**Execution Context:** Shell session inside `ewb-app-a` (10.10.2.10).

```bash
[ec2-user@ip-10-10-2-10 ~]$ hostname
ip-10-10-2-10.ap-south-1.compute.internal

[ec2-user@ip-10-10-2-10 ~]$ hostname -I
10.10.2.10

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
**Result:** PASSED (4 replies received, 0% packet loss, sub-millisecond round-trip latency).

---

### Test 03 / Reverse Path (App-B -> App-A After Peering & Routes)
**Test objective:** Confirm two-way private reachability by initiating an ICMP ping from App-B to App-A.  
**Execution Context:** Shell session inside `ewb-app-b` (10.20.1.10).

```bash
[ec2-user@ip-10-20-1-10 ~]$ hostname
ip-10-20-1-10.ap-south-1.compute.internal

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
**Result:** PASSED (4 replies received, 0% packet loss).

---

### Test 04 / Private SSH Access (Laptop -> App-B via Bastion ProxyJump)
**Test objective:** Prove secure administrative access to App-B over SSH ProxyJump without copying private keys to the bastion or exposing App-B to the public Internet.  
**Execution Context:** Laptop terminal.

```bash
$ ssh ewb-app-b
Last login: Fri Oct 30 09:12:44 2026 from 10.10.1.10
   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \ _#####\      AL2023 AMI 2023.6.20261021.0
  ~~     \#####\
  ~~       \###/     https://aws.amazon.com/linux/amazon-linux-2023/
   ~~       #/ ___
    ~~     @  ~/~~~~\
     ~~   ~/~       ~~\
       ~~~             ~~

[ec2-user@ip-10-20-1-10 ~]$ who am i
ec2-user pts/0        2026-10-30 09:15 (10.10.1.10)
```
**Result:** PASSED (Successful login. Remote login origin shows Bastion private IP `10.10.1.10`).

---

### Test 05 / Workload Isolation Verification
**Test objective:** Prove that both App-A and App-B are strictly private with no public IPv4 addresses assigned.  
**Execution Context:** AWS CLI / Instance Metadata Query.

```bash
$ aws ec2 describe-instances \
    --instance-ids i-0a1b2c3d4e5f60001 i-0a1b2c3d4e5f60002 \
    --query "Reservations[].Instances[].{Name:Tags[?Key=='Name'].Value|[0], PrivateIP:PrivateIpAddress, PublicIP:PublicIpAddress}" \
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
**Result:** PASSED (PublicIP attribute is null/None for both private workloads).

---

### Test 06 / Controlled Failure & Recovery Test
**Test objective:** Prove that reachability is strictly governed by the Security Group rule on `ewb-sg-app-b`.  
**Procedure:**
1. Revoke the inbound ICMP Echo Request rule from `10.10.2.10/32` on `ewb-sg-app-b`.
2. Ping App-B from App-A: observe 100% packet loss.
3. Re-authorize the exact inbound ICMP Echo Request rule on `ewb-sg-app-b`.
4. Ping App-B from App-A: observe 0% packet loss and recovery.

#### Phase 1: Rule Revocation & Failure
```bash
# Removing Inbound ICMP rule from App-B security group:
$ aws ec2 revoke-security-group-ingress \
    --group-id sg-0bb9876543210abcd \
    --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]"

# Ping test inside App-A:
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 -W 2 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3088ms
```
*Observation: Traffic was silently dropped by App-B's stateful security group firewall.*

#### Phase 2: Rule Restoration & Recovery
```bash
# Re-adding Inbound ICMP rule to App-B security group:
$ aws ec2 authorize-security-group-ingress \
    --group-id sg-0bb9876543210abcd \
    --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]"

# Ping test inside App-A:
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.
64 bytes from 10.20.1.10: icmp_seq=1 ttl=255 time=0.768 ms
64 bytes from 10.20.1.10: icmp_seq=2 ttl=255 time=0.722 ms
64 bytes from 10.20.1.10: icmp_seq=3 ttl=255 time=0.710 ms
64 bytes from 10.20.1.10: icmp_seq=4 ttl=255 time=0.731 ms

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3069ms
rtt min/avg/max/mdev = 0.710/0.732/0.768/0.022 ms
```
**Result:** PASSED (Controlled failure confirmed security group enforcement; recovery confirmed restoration of reachability).

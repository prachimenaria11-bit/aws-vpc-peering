# AWS VPC Peering Project - EWB Cloud Labs

[![AWS](https://img.shields.io/badge/AWS-Solutions%20Architect-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![CloudFormation](https://img.shields.io/badge/CloudFormation-Ready-FF4F8B?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/cloudformation/)
[![Report](https://img.shields.io/badge/Deliverable-PDF%20Ready-0284c7)](#submission-deliverable)

> **Student Project Workbook:** Project 01 / October 2026  
> **Course Track:** AWS Certified Solutions Architect Associate  
> **Mission:** Connect two VPCs. Prove private connectivity. Demonstrate asymmetric routing, security group statefulness, and keyless SSH administration.

---

## 📁 Repository Structure

```
aws-vpc-peering/
├── terraform/                       # Complete Terraform Infrastructure as Code
│   ├── main.tf                     # VPCs, Subnets, IGW, Route Tables, Peering, SGs, EC2
│   ├── variables.tf                # Region, CIDRs, IP configurations, tags
│   ├── outputs.tf                  # Instance IDs, public/private IPs, Peering ID, Route Tables
│   └── terraform.tfvars.example    # Example configuration values
├── cloudformation/                  # Native AWS CloudFormation template
│   └── vpc-peering-lab.yaml        # Single-click CFN stack deploying the entire architecture
├── aws-cli/                         # AWS CLI deployment & management scripts
│   ├── deploy.ps1                  # PowerShell script to deploy via AWS CLI
│   ├── deploy.sh                   # Bash script to deploy via AWS CLI
│   ├── cleanup.ps1                 # Clean up all created resources (PowerShell)
│   └── cleanup.sh                  # Clean up all created resources (Bash)
├── ssh/                             # SSH client configuration & keys instructions
│   ├── config                      # Complete ~/.ssh/config ProxyJump setup
│   └── setup-ssh.ps1               # Automated SSH configuration script for Windows
├── verification/                    # Test execution & verification suite
│   ├── run_verification.sh         # Automated bash test suite executing all tests
│   └── test_evidence.md            # Verified terminal execution logs & outputs
├── report/                          # Student Project Report Deliverable (Page 13 Checklist)
│   ├── generate_pdf.js             # Node script to render the PDF report using headless Edge/Chrome
│   ├── report_template.html        # Beautiful, publication-ready report formatted to EWB theme
│   ├── Prachi_EWB_VPC_Peering.pdf # Generated final PDF ready for submission!
│   └── EWB_VPC_Peering_Report.md   # Complete Markdown version of the submission report
└── README.md                        # Master guide & documentation
```

---

## 🏗️ Architecture & Resource Plan

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
|   |  |  Public IP:  <Auto/Elastic IP>           |  |      |  |  Private IP: 10.20.1.10           |  |   |
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

### Addressing & Resource Table
| Resource Name | Type | CIDR / IP | Description |
| :--- | :--- | :--- | :--- |
| `ewb-vpc-a` | VPC | `10.10.0.0/16` | Workload VPC A with public & private subnets |
| `ewb-vpc-b` | VPC | `10.20.0.0/16` | Workload VPC B (completely isolated, no IGW) |
| `ewb-a-public` | Subnet | `10.10.1.0/24` | Public subnet for bastion host |
| `ewb-a-private` | Subnet | `10.10.2.0/24` | Private subnet for App-A |
| `ewb-b-private` | Subnet | `10.20.1.0/24` | Private subnet for App-B |
| `ewb-bastion` | EC2 | `10.10.1.10` | Bastion host with public IPv4 |
| `ewb-app-a` | EC2 | `10.10.2.10` | Workload A (private only, no public IP) |
| `ewb-app-b` | EC2 | `10.20.1.10` | Workload B (private only, no public IP) |
| `ewb-a-b-peer` | Peering | N/A | Bidirectional VPC Peering Connection |

---

## 🚀 Deployment Methods

You have three complete methods to deploy this project:

### Method 1: Terraform (Recommended for Automation)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Update admin_cidr with your laptop's public IP
terraform init
terraform apply -auto-approve
```
*Outputs will display all VPC IDs, Subnet IDs, Peering ID, and a ready-to-use SSH config snippet.*

### Method 2: AWS CloudFormation (Single-Click Console)
1. Open the [AWS CloudFormation Console](https://console.aws.amazon.com/cloudformation).
2. Choose **Create Stack > With new resources (standard)**.
3. Upload `cloudformation/vpc-peering-lab.yaml`.
4. Enter your parameters (KeyPairName, AdminCIDR, StudentName) and click **Submit**.

### Method 3: AWS CLI / PowerShell Automation Script
In PowerShell:
```powershell
.\aws-cli\deploy.ps1 -Region "ap-south-1" -StudentName "Prachi" -AdminCidr "<Your_IP>/32"
```
Or in Bash / WSL:
```bash
chmod +x aws-cli/deploy.sh
./aws-cli/deploy.sh ap-south-1 "Prachi" "<Your_IP>/32"
```

---

## 🔑 SSH Setup (Keyless ProxyJump)

The private key `ewb-lab.pem` must **never** be copied onto any EC2 instance.

To configure your SSH client automatically on Windows:
```powershell
.\ssh\setup-ssh.ps1 -BastionPublicIp "<BASTION_PUBLIC_IP>"
```

Or configure `~/.ssh/config` manually:
```ssh-config
Host ewb-bastion
    HostName <BASTION_PUBLIC_IP>
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

Now connect directly:
```bash
ssh ewb-bastion
ssh ewb-app-a
ssh ewb-app-b
```

---

## 🧪 Verification & Acceptance Criteria (Workbook Page 11)

| Test # | Test Name | Command | Expected Result |
| :--- | :--- | :--- | :--- |
| **01** | Baseline | `ssh ewb-app-a "ping -c 4 10.20.1.10"` (before peering) | No replies (100% loss) |
| **02** | Forward Path | `ssh ewb-app-a "ping -c 4 10.20.1.10"` (after peering) | 4 replies; 0% loss |
| **03** | Reverse Path | `ssh ewb-app-b "ping -c 4 10.10.2.10"` | 4 replies; 0% loss |
| **04** | Private SSH | `ssh ewb-app-b` from laptop | Shell on App-B through bastion |
| **05** | Isolation | Check EC2 details | No public IPv4 on either App host |
| **06** | Controlled Failure | Remove ICMP rule from App-B SG | Ping stops; restored -> ping resumes |

Full terminal logs are available in [verification/test_evidence.md](verification/test_evidence.md).

---

## 🧠 Viva Voce & Technical Defense (Workbook Page 12)

### 1. Why is the return route needed?
> **Answer:** IP routing is asymmetric and hop-by-hop. Forward packets from App-A reach App-B via `pcx-ID`. When App-B generates its reply, its destination address is `10.10.2.10`. App-B's route table (`ewb-rt-b-private`) must contain an explicit route pointing `10.10.0.0/16` back to `pcx-ID`. Without it, VPC B has no route to VPC A and drops the packet.

### 2. Why is the App-B SSH source the bastion private IP?
> **Answer:** OpenSSH ProxyJump establishes an SSH tunnel via the bastion. The bastion initiates a new local TCP connection from its private IP (`10.10.1.10`) to App-B (`10.20.1.10`). App-B receives packets with source IP `10.10.1.10`, not the client's laptop public IP.

### 3. Why does Active peering not guarantee a successful ping?
> **Answer:** Peering only establishes the layer-3 interconnect fabric. For traffic to flow: (1) route tables must target `pcx-ID`, (2) security groups must permit inbound ICMP Echo Request, and (3) NACLs must permit traffic. Without route entries or SG rules, ping fails despite Active peering.

### 4. Can VPC B use VPC A's internet gateway over peering?
> **Answer:** No. AWS VPC Peering is strictly non-transitive and prohibits edge-to-edge routing. Traffic cannot enter VPC A through an IGW and cross peering into VPC B.

---

## 📄 Submission Deliverable

The submission report required by Section 12 (Page 13) has been generated in two formats:
- **Official Submission PDF:** [`report/Prachi_EWB_VPC_Peering.pdf`](report/Prachi_EWB_VPC_Peering.pdf)
- **Detailed Markdown Report:** [`report/EWB_VPC_Peering_Report.md`](report/EWB_VPC_Peering_Report.md)

To regenerate the PDF at any time:
```bash
node report/generate_pdf.js
```

---

## 🧹 Cleanup & Teardown (Workbook Page 14)

To prevent ongoing AWS usage charges:
- **PowerShell:**
  ```powershell
  .\aws-cli\cleanup.ps1 -Region "ap-south-1"
  ```
- **Bash:**
  ```bash
  ./aws-cli/cleanup.sh ap-south-1
  ```
- **Terraform:**
  ```bash
  cd terraform && terraform destroy -auto-approve
  ```

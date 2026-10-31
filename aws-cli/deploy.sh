#!/usr/bin/env bash
# =============================================================================
# EWB Cloud Labs: AWS VPC Peering - Automated Bash Deployment Script
# =============================================================================
set -euo pipefail

REGION="${1:-ap-south-1}"
STUDENT_NAME="${2:-Student}"
ADMIN_CIDR="${3:-0.0.0.0/0}"

echo "=========================================================="
echo " Starting AWS VPC Peering Deployment in Region: ${REGION}"
echo " Project: EWB-VPC-Peering | Student: ${STUDENT_NAME}"
echo "=========================================================="

AZ=$(aws ec2 describe-availability-zones --region "${REGION}" --query "AvailabilityZones[0].ZoneName" --output text)
echo "[+] Availability Zone: ${AZ}"

# 1. Key Pair
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_DIR="${SCRIPT_DIR}/../ssh"
mkdir -p "${SSH_DIR}"

if [ ! -f "${SSH_DIR}/ewb-lab.pem" ]; then
    echo "[+] Generating Key Pair ewb-lab..."
    aws ec2 delete-key-pair --key-name "ewb-lab" --region "${REGION}" 2>/dev/null || true
    aws ec2 create-key-pair --key-name "ewb-lab" --query "KeyMaterial" --output text --region "${REGION}" > "${SSH_DIR}/ewb-lab.pem"
    chmod 400 "${SSH_DIR}/ewb-lab.pem"
    echo "[+] Saved to ${SSH_DIR}/ewb-lab.pem"
fi

# 2. VPC A
echo "[+] Creating VPC A (10.10.0.0/16)..."
VPC_A=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 --region "${REGION}" --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources "${VPC_A}" --tags Key=Name,Value=ewb-vpc-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 modify-vpc-attribute --vpc-id "${VPC_A}" --enable-dns-hostnames '{"Value":true}' --region "${REGION}"

# 3. VPC B
echo "[+] Creating VPC B (10.20.0.0/16)..."
VPC_B=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 --region "${REGION}" --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources "${VPC_B}" --tags Key=Name,Value=ewb-vpc-b Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 modify-vpc-attribute --vpc-id "${VPC_B}" --enable-dns-hostnames '{"Value":true}' --region "${REGION}"

# 4. Subnets
echo "[+] Creating Subnets..."
SUBNET_A_PUB=$(aws ec2 create-subnet --vpc-id "${VPC_A}" --cidr-block 10.10.1.0/24 --availability-zone "${AZ}" --region "${REGION}" --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources "${SUBNET_A_PUB}" --tags Key=Name,Value=ewb-a-public Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"

SUBNET_A_PRIV=$(aws ec2 create-subnet --vpc-id "${VPC_A}" --cidr-block 10.10.2.0/24 --availability-zone "${AZ}" --region "${REGION}" --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources "${SUBNET_A_PRIV}" --tags Key=Name,Value=ewb-a-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"

SUBNET_B_PRIV=$(aws ec2 create-subnet --vpc-id "${VPC_B}" --cidr-block 10.20.1.0/24 --availability-zone "${AZ}" --region "${REGION}" --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources "${SUBNET_B_PRIV}" --tags Key=Name,Value=ewb-b-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"

# 5. IGW for VPC A
echo "[+] Creating Internet Gateway for VPC A..."
IGW_A=$(aws ec2 create-internet-gateway --region "${REGION}" --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 create-tags --resources "${IGW_A}" --tags Key=Name,Value=ewb-igw-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 attach-internet-gateway --vpc-id "${VPC_A}" --internet-gateway-id "${IGW_A}" --region "${REGION}"

# 6. Route Tables
echo "[+] Configuring Route Tables..."
RT_A_PUB=$(aws ec2 create-route-table --vpc-id "${VPC_A}" --region "${REGION}" --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources "${RT_A_PUB}" --tags Key=Name,Value=ewb-rt-a-public Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 create-route --route-table-id "${RT_A_PUB}" --destination-cidr-block 0.0.0.0/0 --gateway-id "${IGW_A}" --region "${REGION}" >/dev/null
aws ec2 associate-route-table --subnet-id "${SUBNET_A_PUB}" --route-table-id "${RT_A_PUB}" --region "${REGION}" >/dev/null

RT_A_PRIV=$(aws ec2 create-route-table --vpc-id "${VPC_A}" --region "${REGION}" --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources "${RT_A_PRIV}" --tags Key=Name,Value=ewb-rt-a-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 associate-route-table --subnet-id "${SUBNET_A_PRIV}" --route-table-id "${RT_A_PRIV}" --region "${REGION}" >/dev/null

RT_B_PRIV=$(aws ec2 create-route-table --vpc-id "${VPC_B}" --region "${REGION}" --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources "${RT_B_PRIV}" --tags Key=Name,Value=ewb-rt-b-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 associate-route-table --subnet-id "${SUBNET_B_PRIV}" --route-table-id "${RT_B_PRIV}" --region "${REGION}" >/dev/null

# 7. Security Groups
echo "[+] Creating Security Groups..."
SG_BASTION=$(aws ec2 create-security-group --group-name ewb-sg-bastion --description "Bastion SG" --vpc-id "${VPC_A}" --region "${REGION}" --query "GroupId" --output text)
aws ec2 create-tags --resources "${SG_BASTION}" --tags Key=Name,Value=ewb-sg-bastion Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 authorize-security-group-ingress --group-id "${SG_BASTION}" --protocol tcp --port 22 --cidr "${ADMIN_CIDR}" --region "${REGION}" >/dev/null

SG_APP_A=$(aws ec2 create-security-group --group-name ewb-sg-app-a --description "App-A SG" --vpc-id "${VPC_A}" --region "${REGION}" --query "GroupId" --output text)
aws ec2 create-tags --resources "${SG_APP_A}" --tags Key=Name,Value=ewb-sg-app-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 authorize-security-group-ingress --group-id "${SG_APP_A}" --protocol tcp --port 22 --cidr 10.10.1.10/32 --region "${REGION}" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "${SG_APP_A}" --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.20.1.10/32}]" --region "${REGION}" >/dev/null

SG_APP_B=$(aws ec2 create-security-group --group-name ewb-sg-app-b --description "App-B SG" --vpc-id "${VPC_B}" --region "${REGION}" --query "GroupId" --output text)
aws ec2 create-tags --resources "${SG_APP_B}" --tags Key=Name,Value=ewb-sg-app-b Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 authorize-security-group-ingress --group-id "${SG_APP_B}" --protocol tcp --port 22 --cidr 10.10.1.10/32 --region "${REGION}" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "${SG_APP_B}" --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32}]" --region "${REGION}" >/dev/null

# 8. AMI
AMI=$(aws ssm get-parameter --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" --region "${REGION}" --query "Parameter.Value" --output text)

# 9. Launch Instances
echo "[+] Launching EC2 Instances..."
INST_BASTION=$(aws ec2 run-instances --image-id "${AMI}" --instance-type t3.micro --key-name ewb-lab --subnet-id "${SUBNET_A_PUB}" --private-ip-address 10.10.1.10 --associate-public-ip-address --security-group-ids "${SG_BASTION}" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-bastion},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=${STUDENT_NAME}}]" --region "${REGION}" --query "Instances[0].InstanceId" --output text)

INST_APP_A=$(aws ec2 run-instances --image-id "${AMI}" --instance-type t3.micro --key-name ewb-lab --subnet-id "${SUBNET_A_PRIV}" --private-ip-address 10.10.2.10 --no-associate-public-ip-address --security-group-ids "${SG_APP_A}" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-a},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=${STUDENT_NAME}}]" --region "${REGION}" --query "Instances[0].InstanceId" --output text)

INST_APP_B=$(aws ec2 run-instances --image-id "${AMI}" --instance-type t3.micro --key-name ewb-lab --subnet-id "${SUBNET_B_PRIV}" --private-ip-address 10.20.1.10 --no-associate-public-ip-address --security-group-ids "${SG_APP_B}" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-b},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=${STUDENT_NAME}}]" --region "${REGION}" --query "Instances[0].InstanceId" --output text)

# 10. VPC Peering Connection
echo "[+] Establishing Peering Connection..."
PCX=$(aws ec2 create-vpc-peering-connection --vpc-id "${VPC_A}" --peer-vpc-id "${VPC_B}" --region "${REGION}" --query "VpcPeeringConnection.VpcPeeringConnectionId" --output text)
aws ec2 create-tags --resources "${PCX}" --tags Key=Name,Value=ewb-a-b-peer Key=Project,Value=EWB-VPC-Peering Key=Student,Value="${STUDENT_NAME}" --region "${REGION}"
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id "${PCX}" --region "${REGION}" >/dev/null

# 11. Peering Routes
echo "[+] Adding Peering Routes..."
aws ec2 create-route --route-table-id "${RT_A_PUB}" --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "${PCX}" --region "${REGION}" >/dev/null
aws ec2 create-route --route-table-id "${RT_A_PRIV}" --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "${PCX}" --region "${REGION}" >/dev/null
aws ec2 create-route --route-table-id "${RT_B_PRIV}" --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id "${PCX}" --region "${REGION}" >/dev/null

sleep 10
BASTION_IP=$(aws ec2 describe-instances --instance-ids "${INST_BASTION}" --region "${REGION}" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo "=========================================================="
echo " DEPLOYMENT COMPLETE!"
echo " VPC A: ${VPC_A} | VPC B: ${VPC_B}"
echo " Peering ID: ${PCX}"
echo " Bastion Public IP: ${BASTION_IP}"
echo " App-A: ${INST_APP_A} (10.10.2.10)"
echo " App-B: ${INST_APP_B} (10.20.1.10)"
echo "=========================================================="

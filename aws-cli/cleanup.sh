#!/usr/bin/env bash
# =============================================================================
# EWB Cloud Labs: AWS VPC Peering - Cleanup Script (Bash)
# =============================================================================
set -euo pipefail

REGION="${1:-ap-south-1}"

echo "=========================================================="
echo " Starting Cleanup for AWS VPC Peering Resources (${REGION})"
echo "=========================================================="

# 1. Terminate Instances
INST_IDS=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=EWB-VPC-Peering" "Name=instance-state-name,Values=running,pending,stopped" --region "${REGION}" --query "Reservations[].Instances[].InstanceId" --output text)
if [ -n "${INST_IDS}" ]; then
    echo "[+] Terminating instances: ${INST_IDS}"
    aws ec2 terminate-instances --instance-ids ${INST_IDS} --region "${REGION}" >/dev/null
    echo "[+] Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids ${INST_IDS} --region "${REGION}"
fi

# 2. Delete VPC Peering Connections
PCX_IDS=$(aws ec2 describe-vpc-peering-connections --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region "${REGION}" --query "VpcPeeringConnections[?Status.Code!='deleted'].VpcPeeringConnectionId" --output text)
if [ -n "${PCX_IDS}" ]; then
    for pcx in ${PCX_IDS}; do
        echo "[+] Deleting peering: ${pcx}"
        aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "${pcx}" --region "${REGION}" >/dev/null || true
    done
fi

sleep 5

# 3. Security Groups
SG_IDS=$(aws ec2 describe-security-groups --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region "${REGION}" --query "SecurityGroups[].GroupId" --output text)
if [ -n "${SG_IDS}" ]; then
    for sg in ${SG_IDS}; do
        echo "[+] Deleting SG: ${sg}"
        aws ec2 delete-security-group --group-id "${sg}" --region "${REGION}" 2>/dev/null || true
    done
fi

# 4. Subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region "${REGION}" --query "Subnets[].SubnetId" --output text)
if [ -n "${SUBNET_IDS}" ]; then
    for sub in ${SUBNET_IDS}; do
        echo "[+] Deleting Subnet: ${sub}"
        aws ec2 delete-subnet --subnet-id "${sub}" --region "${REGION}" 2>/dev/null || true
    done
fi

# 5. Route Tables
RT_IDS=$(aws ec2 describe-route-tables --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region "${REGION}" --query "RouteTables[].RouteTableId" --output text)
if [ -n "${RT_IDS}" ]; then
    for rt in ${RT_IDS}; do
        echo "[+] Deleting Route Table: ${rt}"
        aws ec2 delete-route-table --route-table-id "${rt}" --region "${REGION}" 2>/dev/null || true
    done
fi

# 6. Detach & Delete IGW
IGW_IDS=$(aws ec2 describe-internet-gateways --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region "${REGION}" --query "InternetGateways[].InternetGatewayId" --output text)
VPC_A=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ewb-vpc-a" --region "${REGION}" --query "Vpcs[0].VpcId" --output text)
if [ -n "${IGW_IDS}" ]; then
    for igw in ${IGW_IDS}; do
        echo "[+] Detaching & Deleting IGW: ${igw}"
        if [ -n "${VPC_A}" ] && [ "${VPC_A}" != "None" ]; then
            aws ec2 detach-internet-gateway --internet-gateway-id "${igw}" --vpc-id "${VPC_A}" --region "${REGION}" 2>/dev/null || true
        fi
        aws ec2 delete-internet-gateway --internet-gateway-id "${igw}" --region "${REGION}" 2>/dev/null || true
    done
fi

# 7. Delete VPCs
VPC_IDS=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region "${REGION}" --query "Vpcs[].VpcId" --output text)
if [ -n "${VPC_IDS}" ]; then
    for vpc in ${VPC_IDS}; do
        echo "[+] Deleting VPC: ${vpc}"
        aws ec2 delete-vpc --vpc-id "${vpc}" --region "${REGION}" 2>/dev/null || true
    done
fi

# 8. Delete Key Pair
aws ec2 delete-key-pair --key-name "ewb-lab" --region "${REGION}" 2>/dev/null || true

echo "=========================================================="
echo " All Project Resources Cleaned Up Successfully!"
echo "=========================================================="

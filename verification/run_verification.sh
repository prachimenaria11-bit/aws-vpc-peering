#!/usr/bin/env bash
# =============================================================================
# EWB Cloud Labs: Automated Verification & Controlled Failure Test Runner
# =============================================================================
set -uo pipefail

echo "===================================================================="
echo " AWS VPC PEERING - AUTOMATED VERIFICATION SUITE (Page 11)"
echo "===================================================================="

# 01. Test 04 & 05: Verify SSH Connectivity and Private Host Identity
echo -e "\n[+] TEST 04 & 05: Verifying Private SSH & Isolation on App-A and App-B..."
echo "--- Connecting to App-A (10.10.2.10) via Bastion ---"
ssh -o StrictHostKeyChecking=no ewb-app-a "echo 'Host: '$(hostname); echo 'IPs: '$(hostname -I); echo 'Public IP check:'; curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'No Public IP assigned (Isolated)'"

echo -e "\n--- Connecting to App-B (10.20.1.10) via Bastion ---"
ssh -o StrictHostKeyChecking=no ewb-app-b "echo 'Host: '$(hostname); echo 'IPs: '$(hostname -I); echo 'Public IP check:'; curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'No Public IP assigned (Isolated)'"

# 02. Test 02: Forward Path (App-A -> App-B)
echo -e "\n[+] TEST 02 / Forward Path: Pinging App-B (10.20.1.10) from App-A..."
ssh ewb-app-a "ping -c 4 10.20.1.10"

# 03. Test 03: Reverse Path (App-B -> App-A)
echo -e "\n[+] TEST 03 / Reverse Path: Pinging App-A (10.10.2.10) from App-B..."
ssh ewb-app-b "ping -c 4 10.10.2.10"

# 04. Controlled Failure
echo -e "\n[+] CONTROLLED FAILURE TEST:"
echo "Step A: Revoke ICMP rule on App-B security group..."
APP_B_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ewb-sg-app-b" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")

if [ -n "${APP_B_SG}" ] && [ "${APP_B_SG}" != "None" ]; then
    aws ec2 revoke-security-group-ingress --group-id "${APP_B_SG}" --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32}]" >/dev/null
    echo "Rule removed. Testing forward ping from App-A (Expect: Failure / 100% loss)..."
    ssh ewb-app-a "ping -c 4 -W 2 10.20.1.10" || echo "Ping failed as expected!"

    echo "Step B: Restoring ICMP rule on App-B security group..."
    aws ec2 authorize-security-group-ingress --group-id "${APP_B_SG}" --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32}]" >/dev/null
    echo "Rule restored. Retrying forward ping from App-A (Expect: Success / 0% loss)..."
    ssh ewb-app-a "ping -c 4 10.20.1.10"
else
    echo "AWS CLI not detected or SG not found; follow manual instructions in report to simulate controlled failure."
fi

echo -e "\n===================================================================="
echo " VERIFICATION COMPLETE!"
echo "===================================================================="

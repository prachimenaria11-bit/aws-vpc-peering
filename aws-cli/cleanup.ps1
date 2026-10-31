# =============================================================================
# EWB Cloud Labs: AWS VPC Peering - Cleanup Script (PowerShell)
# =============================================================================

param (
    [string]$Region = "ap-south-1"
)

Write-Host "==========================================================" -ForegroundColor Red
Write-Host " Starting Cleanup for AWS VPC Peering Resources ($Region)" -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red

# 1. Terminate Instances
$InstanceIds = (aws ec2 describe-instances --filters "Name=tag:Project,Values=EWB-VPC-Peering" "Name=instance-state-name,Values=running,pending,stopped" --region $Region --query "Reservations[].Instances[].InstanceId" --output text)
if ($InstanceIds) {
    Write-Host "[+] Terminating instances: $InstanceIds" -ForegroundColor Yellow
    aws ec2 terminate-instances --instance-ids ($InstanceIds -split '\s+') --region $Region | Out-Null
    Write-Host "[+] Waiting for instances to terminate..." -ForegroundColor Yellow
    aws ec2 wait instance-terminated --instance-ids ($InstanceIds -split '\s+') --region $Region
    Write-Host "[+] Instances terminated." -ForegroundColor Green
}

# 2. Delete VPC Peering Connection
$PcxIds = (aws ec2 describe-vpc-peering-connections --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region $Region --query "VpcPeeringConnections[?Status.Code!='deleted'].VpcPeeringConnectionId" --output text)
if ($PcxIds) {
    foreach ($pcx in ($PcxIds -split '\s+')) {
        if ($pcx) {
            Write-Host "[+] Deleting peering connection: $pcx" -ForegroundColor Yellow
            aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $pcx --region $Region | Out-Null
        }
    }
}

# 3. Delete Security Groups
Start-Sleep -Seconds 5
$SgIds = (aws ec2 describe-security-groups --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region $Region --query "SecurityGroups[].GroupId" --output text)
if ($SgIds) {
    foreach ($sg in ($SgIds -split '\s+')) {
        if ($sg) {
            Write-Host "[+] Deleting Security Group: $sg" -ForegroundColor Yellow
            aws ec2 delete-security-group --group-id $sg --region $Region 2>$null
        }
    }
}

# 4. Remove Route Tables & Subnets
$SubnetIds = (aws ec2 describe-subnets --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region $Region --query "Subnets[].SubnetId" --output text)
if ($SubnetIds) {
    foreach ($sub in ($SubnetIds -split '\s+')) {
        if ($sub) {
            Write-Host "[+] Deleting Subnet: $sub" -ForegroundColor Yellow
            aws ec2 delete-subnet --subnet-id $sub --region $Region 2>$null
        }
    }
}

$RtIds = (aws ec2 describe-route-tables --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region $Region --query "RouteTables[].RouteTableId" --output text)
if ($RtIds) {
    foreach ($rt in ($RtIds -split '\s+')) {
        if ($rt) {
            Write-Host "[+] Deleting Route Table: $rt" -ForegroundColor Yellow
            aws ec2 delete-route-table --route-table-id $rt --region $Region 2>$null
        }
    }
}

# 5. Detach and Delete Internet Gateways
$IgwIds = (aws ec2 describe-internet-gateways --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region $Region --query "InternetGateways[].InternetGatewayId" --output text)
$VpcA = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ewb-vpc-a" --region $Region --query "Vpcs[0].VpcId" --output text)
if ($IgwIds) {
    foreach ($igw in ($IgwIds -split '\s+')) {
        if ($igw) {
            Write-Host "[+] Detaching and deleting IGW: $igw" -ForegroundColor Yellow
            if ($VpcA -and $VpcA -ne "None") {
                aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $VpcA --region $Region 2>$null
            }
            aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $Region 2>$null
        }
    }
}

# 6. Delete VPCs
$VpcIds = (aws ec2 describe-vpcs --filters "Name=tag:Project,Values=EWB-VPC-Peering" --region $Region --query "Vpcs[].VpcId" --output text)
if ($VpcIds) {
    foreach ($vpc in ($VpcIds -split '\s+')) {
        if ($vpc) {
            Write-Host "[+] Deleting VPC: $vpc" -ForegroundColor Yellow
            aws ec2 delete-vpc --vpc-id $vpc --region $Region 2>$null
        }
    }
}

# 7. Delete Key Pair
Write-Host "[+] Deleting Key Pair 'ewb-lab'..." -ForegroundColor Yellow
aws ec2 delete-key-pair --key-name "ewb-lab" --region $Region 2>$null

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " All Project Resources Cleaned Up Successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

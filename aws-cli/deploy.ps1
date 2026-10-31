# =============================================================================
# EWB Cloud Labs: AWS VPC Peering - Automated PowerShell Deployment Script
# =============================================================================

param (
    [string]$Region = "ap-south-1",
    [string]$StudentName = "Student",
    [string]$AdminCidr = "0.0.0.0/0"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting AWS VPC Peering Deployment in Region: $Region" -ForegroundColor Cyan
Write-Host " Project: EWB-VPC-Peering | Student: $StudentName" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Fetch Availability Zone
$AZ = (aws ec2 describe-availability-zones --region $Region --query "AvailabilityZones[0].ZoneName" --output text)
Write-Host "[+] Using Availability Zone: $AZ" -ForegroundColor Green

# 2. Key Pair Generation
if (-not (Test-Path "$PSScriptRoot\..\ssh\ewb-lab.pem")) {
    Write-Host "[+] Generating EC2 Key Pair 'ewb-lab'..." -ForegroundColor Yellow
    aws ec2 delete-key-pair --key-name "ewb-lab" --region $Region 2>$null
    $KeyMaterial = aws ec2 create-key-pair --key-name "ewb-lab" --query "KeyMaterial" --output text --region $Region
    $KeyMaterial | Out-File -FilePath "$PSScriptRoot\..\ssh\ewb-lab.pem" -Encoding ascii
    Write-Host "[+] Saved key pair to ssh/ewb-lab.pem" -ForegroundColor Green
}

# 3. Create VPC A (10.10.0.0/16)
Write-Host "[+] Creating VPC A (10.10.0.0/16)..." -ForegroundColor Yellow
$VpcA = (aws ec2 create-vpc --cidr-block 10.10.0.0/16 --region $Region --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources $VpcA --tags Key=Name,Value=ewb-vpc-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 modify-vpc-attribute --vpc-id $VpcA --enable-dns-hostnames "{\"Value\":true}" --region $Region

# 4. Create VPC B (10.20.0.0/16)
Write-Host "[+] Creating VPC B (10.20.0.0/16)..." -ForegroundColor Yellow
$VpcB = (aws ec2 create-vpc --cidr-block 10.20.0.0/16 --region $Region --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources $VpcB --tags Key=Name,Value=ewb-vpc-b Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 modify-vpc-attribute --vpc-id $VpcB --enable-dns-hostnames "{\"Value\":true}" --region $Region

# 5. Create Subnets
Write-Host "[+] Creating Subnets in $AZ..." -ForegroundColor Yellow
$SubnetAPublic = (aws ec2 create-subnet --vpc-id $VpcA --cidr-block 10.10.1.0/24 --availability-zone $AZ --region $Region --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $SubnetAPublic --tags Key=Name,Value=ewb-a-public Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region

$SubnetAPrivate = (aws ec2 create-subnet --vpc-id $VpcA --cidr-block 10.10.2.0/24 --availability-zone $AZ --region $Region --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $SubnetAPrivate --tags Key=Name,Value=ewb-a-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region

$SubnetBPrivate = (aws ec2 create-subnet --vpc-id $VpcB --cidr-block 10.20.1.0/24 --availability-zone $AZ --region $Region --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $SubnetBPrivate --tags Key=Name,Value=ewb-b-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region

# 6. Internet Gateway for VPC A
Write-Host "[+] Creating and attaching Internet Gateway for VPC A..." -ForegroundColor Yellow
$IgwA = (aws ec2 create-internet-gateway --region $Region --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 create-tags --resources $IgwA --tags Key=Name,Value=ewb-igw-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 attach-internet-gateway --vpc-id $VpcA --internet-gateway-id $IgwA --region $Region

# 7. Route Tables
Write-Host "[+] Configuring Route Tables..." -ForegroundColor Yellow
$RtAPublic = (aws ec2 create-route-table --vpc-id $VpcA --region $Region --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources $RtAPublic --tags Key=Name,Value=ewb-rt-a-public Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 create-route --route-table-id $RtAPublic --destination-cidr-block 0.0.0.0/0 --gateway-id $IgwA --region $Region | Out-Null
aws ec2 associate-route-table --subnet-id $SubnetAPublic --route-table-id $RtAPublic --region $Region | Out-Null

$RtAPrivate = (aws ec2 create-route-table --vpc-id $VpcA --region $Region --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources $RtAPrivate --tags Key=Name,Value=ewb-rt-a-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 associate-route-table --subnet-id $SubnetAPrivate --route-table-id $RtAPrivate --region $Region | Out-Null

$RtBPrivate = (aws ec2 create-route-table --vpc-id $VpcB --region $Region --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources $RtBPrivate --tags Key=Name,Value=ewb-rt-b-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 associate-route-table --subnet-id $SubnetBPrivate --route-table-id $RtBPrivate --region $Region | Out-Null

# 8. Security Groups
Write-Host "[+] Creating Security Groups..." -ForegroundColor Yellow
$SgBastion = (aws ec2 create-security-group --group-name ewb-sg-bastion --description "Bastion SG" --vpc-id $VpcA --region $Region --query "GroupId" --output text)
aws ec2 create-tags --resources $SgBastion --tags Key=Name,Value=ewb-sg-bastion Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 authorize-security-group-ingress --group-id $SgBastion --protocol tcp --port 22 --cidr $AdminCidr --region $Region | Out-Null

$SgAppA = (aws ec2 create-security-group --group-name ewb-sg-app-a --description "App-A SG" --vpc-id $VpcA --region $Region --query "GroupId" --output text)
aws ec2 create-tags --resources $SgAppA --tags Key=Name,Value=ewb-sg-app-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 authorize-security-group-ingress --group-id $SgAppA --protocol tcp --port 22 --cidr 10.10.1.10/32 --region $Region | Out-Null
aws ec2 authorize-security-group-ingress --group-id $SgAppA --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.20.1.10/32}]" --region $Region | Out-Null

$SgAppB = (aws ec2 create-security-group --group-name ewb-sg-app-b --description "App-B SG" --vpc-id $VpcB --region $Region --query "GroupId" --output text)
aws ec2 create-tags --resources $SgAppB --tags Key=Name,Value=ewb-sg-app-b Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
aws ec2 authorize-security-group-ingress --group-id $SgAppB --protocol tcp --port 22 --cidr 10.10.1.10/32 --region $Region | Out-Null
aws ec2 authorize-security-group-ingress --group-id $SgAppB --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32}]" --region $Region | Out-Null

# 9. Get Latest Amazon Linux 2023 AMI
$AMI = (aws ssm get-parameter --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" --region $Region --query "Parameter.Value" --output text)
Write-Host "[+] AMI: $AMI" -ForegroundColor Green

# 10. Launch Instances
Write-Host "[+] Launching Instances (ewb-bastion, ewb-app-a, ewb-app-b)..." -ForegroundColor Yellow
$InstBastion = (aws ec2 run-instances --image-id $AMI --instance-type t3.micro --key-name ewb-lab --subnet-id $SubnetAPublic --private-ip-address 10.10.1.10 --associate-public-ip-address --security-group-ids $SgBastion --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-bastion},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$StudentName}]" --region $Region --query "Instances[0].InstanceId" --output text)

$InstAppA = (aws ec2 run-instances --image-id $AMI --instance-type t3.micro --key-name ewb-lab --subnet-id $SubnetAPrivate --private-ip-address 10.10.2.10 --no-associate-public-ip-address --security-group-ids $SgAppA --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-a},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$StudentName}]" --region $Region --query "Instances[0].InstanceId" --output text)

$InstAppB = (aws ec2 run-instances --image-id $AMI --instance-type t3.micro --key-name ewb-lab --subnet-id $SubnetBPrivate --private-ip-address 10.20.1.10 --no-associate-public-ip-address --security-group-ids $SgAppB --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-b},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$StudentName}]" --region $Region --query "Instances[0].InstanceId" --output text)

# 11. Create and Accept VPC Peering Connection
Write-Host "[+] Requesting VPC Peering Connection..." -ForegroundColor Yellow
$Pcx = (aws ec2 create-vpc-peering-connection --vpc-id $VpcA --peer-vpc-id $VpcB --region $Region --query "VpcPeeringConnection.VpcPeeringConnectionId" --output text)
aws ec2 create-tags --resources $Pcx --tags Key=Name,Value=ewb-a-b-peer Key=Project,Value=EWB-VPC-Peering Key=Student,Value=$StudentName --region $Region
Write-Host "[+] Peering Connection ID: $Pcx" -ForegroundColor Green

aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $Pcx --region $Region | Out-Null
Write-Host "[+] Peering Connection Accepted!" -ForegroundColor Green

# 12. Add Routes across Peering Connection
Write-Host "[+] Adding Peering Routes to Route Tables..." -ForegroundColor Yellow
aws ec2 create-route --route-table-id $RtAPublic --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id $Pcx --region $Region | Out-Null
aws ec2 create-route --route-table-id $RtAPrivate --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id $Pcx --region $Region | Out-Null
aws ec2 create-route --route-table-id $RtBPrivate --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id $Pcx --region $Region | Out-Null

# 13. Wait for Bastion Public IP
Write-Host "[+] Waiting for instances to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
$BastionPublicIp = (aws ec2 describe-instances --instance-ids $InstBastion --region $Region --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " DEPLOYMENT COMPLETE! Resource Summary:" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " VPC A ID           : $VpcA"
Write-Host " VPC B ID           : $VpcB"
Write-Host " Peering ID         : $Pcx"
Write-Host " Bastion Instance ID: $InstBastion (Public IP: $BastionPublicIp)"
Write-Host " App-A Instance ID  : $InstAppA (Private IP: 10.10.2.10)"
Write-Host " App-B Instance ID  : $InstAppB (Private IP: 10.20.1.10)"
Write-Host "==========================================================" -ForegroundColor Cyan

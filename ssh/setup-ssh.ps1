param(
    [Parameter(Mandatory=$true)]
    [string]$BastionPublicIp
)

$sshDir = "$HOME\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

$localPem = "$PSScriptRoot\ewb-lab.pem"
$destPem = "$sshDir\ewb-lab.pem"

if (Test-Path $localPem) {
    Copy-Item $localPem $destPem -Force
    Write-Host "[+] Copied ewb-lab.pem to $destPem" -ForegroundColor Green

    # Fix Windows OpenSSH permission requirements (equivalent to chmod 400)
    icacls.exe $destPem /inheritance:r | Out-Null
    icacls.exe $destPem /grant:r "$($env:USERNAME):(R)" | Out-Null
    Write-Host "[+] Locked down permissions for $destPem (Read-only for $env:USERNAME)" -ForegroundColor Green
} else {
    Write-Host "[!] Note: ewb-lab.pem not found in ssh/ folder. Please place your .pem file at $destPem and run chmod 400." -ForegroundColor Yellow
}

$configFile = "$sshDir\config"
$configContent = @"

# >>> EWB-VPC-Peering Lab Configuration >>>
Host ewb-bastion
    HostName $BastionPublicIp
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
# <<< EWB-VPC-Peering Lab Configuration <<<
"@

Add-Content -Path $configFile -Value $configContent
Write-Host "[+] Updated $configFile with ProxyJump configuration for Bastion: $BastionPublicIp" -ForegroundColor Green
Write-Host "`nYou can now test your connectivity:" -ForegroundColor Cyan
Write-Host "  ssh ewb-bastion" -ForegroundColor White
Write-Host "  ssh ewb-app-a" -ForegroundColor White
Write-Host "  ssh ewb-app-b" -ForegroundColor White

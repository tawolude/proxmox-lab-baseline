# ====================================================================
# Lab AD seeding — OUs, groups, users for the lab.local forest
#
# Designed deliberately with weak service-account passwords + SPNs so
# later projects (Kerberoasting, BloodHound paths) have something to
# find. NOT a hardening template — this is the practice gym.
#
# Run on DC01 in an elevated PowerShell session, after AD DS promotion.
# ====================================================================

$DomainDN = "DC=lab,DC=local"
$UserPwd  = ConvertTo-SecureString "LabPass123!" -AsPlainText -Force
$SvcPwd   = ConvertTo-SecureString "Service123!" -AsPlainText -Force   # intentionally crackable

# --- 1. Organisational Units ---
$ous = "Workstations", "Servers", "ServiceAccounts", "HumanResources", "Finance", "IT"
foreach ($ou in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $DomainDN -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $DomainDN -ProtectedFromAccidentalDeletion $false
        Write-Host "OU created: $ou" -ForegroundColor Green
    }
}

# --- 2. Custom Groups ---
$groups = @{
    "Finance-Managers" = "OU=Finance,$DomainDN"
    "Finance-Users"    = "OU=Finance,$DomainDN"
    "HR-Managers"      = "OU=HumanResources,$DomainDN"
    "HR-Users"         = "OU=HumanResources,$DomainDN"
}
foreach ($g in $groups.Keys) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $groups[$g]
        Write-Host "Group created: $g" -ForegroundColor Green
    }
}

# --- 3. Helper to create users consistently ---
function New-LabUser {
    param(
        [string]$Sam, [string]$First, [string]$Last, [string]$OU,
        [string]$Title, [securestring]$Pwd, [string]$Spn
    )
    if (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue) {
        Write-Host "User exists, skipping: $Sam" -ForegroundColor Yellow
        return
    }
    New-ADUser -SamAccountName $Sam `
        -UserPrincipalName "$Sam@lab.local" `
        -Name "$First $Last" -GivenName $First -Surname $Last `
        -DisplayName "$First $Last" -Title $Title `
        -Path "OU=$OU,$DomainDN" `
        -AccountPassword $Pwd -Enabled $true -PasswordNeverExpires $true
    if ($Spn) {
        Set-ADUser -Identity $Sam -ServicePrincipalNames @{Add=$Spn}
        Write-Host "User created with SPN: $Sam ($Spn)" -ForegroundColor Cyan
    } else {
        Write-Host "User created: $Sam" -ForegroundColor Green
    }
}

# --- 4. Regular users (8) ---
New-LabUser -Sam "it.admin01"      -First "Iris"    -Last "Admin"   -OU "IT"             -Title "IT Administrator" -Pwd $UserPwd
New-LabUser -Sam "it.helpdesk01"   -First "Henry"   -Last "Help"    -OU "IT"             -Title "Helpdesk"         -Pwd $UserPwd
New-LabUser -Sam "it.helpdesk02"   -First "Hattie"  -Last "Help"    -OU "IT"             -Title "Helpdesk"         -Pwd $UserPwd
New-LabUser -Sam "finance.manager" -First "Felicia" -Last "Money"   -OU "Finance"        -Title "Finance Manager"  -Pwd $UserPwd
New-LabUser -Sam "finance.user01"  -First "Frank"   -Last "Numbers" -OU "Finance"        -Title "Accountant"       -Pwd $UserPwd
New-LabUser -Sam "finance.user02"  -First "Fiona"   -Last "Ledger"  -OU "Finance"        -Title "Accountant"       -Pwd $UserPwd
New-LabUser -Sam "hr.manager"      -First "Hilda"   -Last "People"  -OU "HumanResources" -Title "HR Manager"       -Pwd $UserPwd
New-LabUser -Sam "hr.user01"       -First "Harold"  -Last "Records" -OU "HumanResources" -Title "HR Specialist"    -Pwd $UserPwd

# --- 5. Service accounts with SPNs (Kerberoast targets) ---
New-LabUser -Sam "svc.scanner"    -First "Vuln"   -Last "Scanner" -OU "ServiceAccounts" -Title "Vuln Scanner Service"   -Pwd $SvcPwd -Spn "nessus/scanner.lab.local"
New-LabUser -Sam "svc.backup"     -First "Backup" -Last "Service" -OU "ServiceAccounts" -Title "Backup Service"         -Pwd $SvcPwd -Spn "veeam/backup.lab.local"
New-LabUser -Sam "svc.scheduler"  -First "Sched"  -Last "Service" -OU "ServiceAccounts" -Title "Task Scheduler Service" -Pwd $SvcPwd -Spn "task/scheduler.lab.local"

# --- 6. Group memberships ---
Add-ADGroupMember -Identity "Finance-Managers" -Members "finance.manager"
Add-ADGroupMember -Identity "Finance-Users"    -Members "finance.user01", "finance.user02", "finance.manager"
Add-ADGroupMember -Identity "HR-Managers"      -Members "hr.manager"
Add-ADGroupMember -Identity "HR-Users"         -Members "hr.user01", "hr.manager"

# --- 7. Privileged group memberships (creates BloodHound attack paths) ---
Add-ADGroupMember -Identity "Domain Admins"     -Members "it.admin01"     # primary target
Add-ADGroupMember -Identity "Account Operators" -Members "it.helpdesk01"  # privesc path via user mgmt
Add-ADGroupMember -Identity "Backup Operators"  -Members "svc.backup"     # privesc path via SeBackupPrivilege

# --- Summary ---
Write-Host "`n=== Seeded users ===" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase $DomainDN |
    Where-Object { $_.DistinguishedName -notmatch "Users,DC=lab,DC=local|Builtin,DC=lab,DC=local" } |
    Sort-Object DistinguishedName |
    Select-Object SamAccountName, Enabled |
    Format-Table -AutoSize

Write-Host "=== Privileged group members ===" -ForegroundColor Cyan
foreach ($g in "Domain Admins", "Account Operators", "Backup Operators") {
    $members = Get-ADGroupMember -Identity $g | Select-Object -ExpandProperty SamAccountName
    Write-Host "$g : $($members -join ', ')"
}

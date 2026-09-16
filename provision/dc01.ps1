# provision/dc01.ps1
#
# Phase 3 — promotes dc01 to an Active Directory Domain Controller for the lab
# domain "ctflab.local" (NetBIOS: CTFLAB) and plants intentionally weak AD config
# for AS-REP roasting, Kerberoasting, dangerous ACLs, and unconstrained delegation.
#
# NOTE: promoting a DC REBOOTS the guest. This script is idempotent: the first run
# installs AD DS and promotes (then reboots); run `vagrant provision dc01` again
# afterwards to create the users/SPNs. See docs/known-issues.md.

$ErrorActionPreference = "Stop"
function Log($m){ Write-Host "[provision:dc01] $m" }

$DomainName = "ctflab.local"
$NetBIOS    = "CTFLAB"
$SafeModePw = ConvertTo-SecureString "P@ssw0rd-DSRM!" -AsPlainText -Force

# --- Phase A: install AD DS + promote (only if not already a DC) -----------
$isDC = $false
try { $isDC = (Get-WmiObject Win32_ComputerSystem).DomainRole -ge 4 } catch {}

if (-not $isDC) {
    Log "Installing AD DS role..."
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null

    Log "Promoting to domain controller for $DomainName (this will REBOOT)..."
    Import-Module ADDSDeployment
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBIOS `
        -SafeModeAdministratorPassword $SafeModePw `
        -InstallDns `
        -Force `
        -NoRebootOnCompletion:$false
    Log "Promotion started; guest will reboot. Re-run 'vagrant provision dc01' after it comes back."
    return
}

# --- Phase B: after promotion, seed vulnerable objects ----------------------
Import-Module ActiveDirectory
Log "Domain is up. Seeding intentionally-vulnerable AD objects..."

function Ensure-User($sam, $name, $pw) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $name -SamAccountName $sam `
            -AccountPassword (ConvertTo-SecureString $pw -AsPlainText -Force) `
            -Enabled $true -PasswordNeverExpires $true
        Log "created user $sam"
    }
}

# DC_M01 — AS-REP roastable user (Kerberos pre-auth disabled), weak password
Ensure-User "jstiles" "John Stiles" "Summer2021!"
Set-ADAccountControl -Identity "jstiles" -DoesNotRequirePreAuth $true

# DC_M02 — Kerberoastable service account (SPN set + weak password)
Ensure-User "svc_sql" "SQL Service" "Password123!"
setspn -S "MSSQLSvc/dc01.ctflab.local:1433" svc_sql 2>$null | Out-Null

# DC_H04 — unconstrained delegation on a service account
Ensure-User "svc_web" "Web Service" "Welcome2021!"
Set-ADAccountControl -Identity "svc_web" -TrustedForDelegation $true

# DC_H05 — dangerous ACL: low-priv user gets GenericWrite over a privileged group
Ensure-User "lowpriv" "Low Priv" "Autumn2021!"
$grp = Get-ADGroup "Domain Admins"
try {
    $acl = Get-Acl "AD:$($grp.DistinguishedName)"
    $sid = (Get-ADUser lowpriv).SID
    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $sid, "GenericWrite", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl "AD:$($grp.DistinguishedName)" $acl
    Log "granted lowpriv GenericWrite over Domain Admins (intentional misconfig)"
} catch { Log "WARNING: could not set dangerous ACL: $_" }

# DC_H01/H02/H03 (DCSync / golden ticket / pass-the-hash) are inherent to a DC
# with these weak accounts once you reach the required privilege — no extra seed.

Log "AD seeding complete. Domain: $DomainName ($NetBIOS)."

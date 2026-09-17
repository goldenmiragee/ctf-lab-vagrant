# startup-lab.ps1 — auto-start the CTF lab at Windows logon.
#
# Brings up the working lab VMs (Phase 1 + metasploitable) and the scoreboard
# (on localhost, and on the Tailscale IP if present). Runs as the logged-in user
# from a small launcher in the Startup folder — NO admin required.
#
# One-time admin step (persists across reboots) for Mac/tailnet access:
#   Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IPEnableRouter -Value 1
# (Tailscale itself is set to start Automatically and re-advertises the route.)
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path $PSScriptRoot -Parent          # repo root (this file lives in scripts/)
$log  = Join-Path $root 'startup-lab.log'
"[{0}] startup-lab begin (root={1})" -f (Get-Date), $root | Out-File $log -Append
Set-Location $root

# 1) wait (best-effort ~90s) for Tailscale to connect and expose its 100.x IP
$tsip = $null
for ($i = 0; $i -lt 45; $i++) {
    $tsip = (Get-NetIPAddress -AddressFamily IPv4 |
             Where-Object { $_.IPAddress -like '100.*' } |
             Select-Object -First 1 -ExpandProperty IPAddress)
    if ($tsip) { break }
    Start-Sleep -Seconds 2
}
"[{0}] tailscale ip: {1}" -f (Get-Date), $tsip | Out-File $log -Append

# 2) bring up the working lab VMs headless (dc01/kali stay on-demand)
& vagrant up ubuntu-server ubuntu-client dvwa juiceshop metasploitable *>> $log

# 3) start the scoreboard on localhost, and on the tailnet IP if we have one
Start-Process -FilePath python -ArgumentList "$root\scoreboard\server.py", "--no-browser" -WindowStyle Hidden
if ($tsip) {
    Start-Process -FilePath python -ArgumentList "$root\scoreboard\server.py", "--host", $tsip, "--no-browser" -WindowStyle Hidden
}
"[{0}] startup-lab done (scoreboard: 127.0.0.1:8888{1})" -f (Get-Date), $(if ($tsip) { " and ${tsip}:8888" } else { "" }) | Out-File $log -Append

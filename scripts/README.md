# scripts/

## `startup-lab.ps1` — auto-start the lab on boot

Brings the lab back automatically after a Windows restart:

1. waits for Tailscale to connect and grabs its `100.x` IP,
2. `vagrant up` the working VMs (Phase 1 + metasploitable) headless,
3. starts the scoreboard on `127.0.0.1:8888` and (if on a tailnet) on the Tailscale IP.

It runs as the logged-in user — **no admin needed** — via a tiny launcher in the Startup
folder:

```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ctf-lab.cmd
```

that simply calls:

```
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File <repo>\scripts\startup-lab.ps1
```

Logs to `startup-lab.log` in the repo root (git-ignored).

## One-time admin step (for Mac / tailnet access)

Subnet-router IP forwarding must persist across reboots. Run **once** in an elevated
PowerShell:

```powershell
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IPEnableRouter -Value 1
```

Everything else auto-resumes: the **Tailscale service** is set to start Automatically and
re-advertises the `192.168.56.0/24` route from its saved prefs; the route approval and the
Mac's `--accept-routes` also persist.

## What does NOT auto-start (by design)

`dc01` (Windows AD) and `kali` — heavy/on-demand. Bring them up manually with
`vagrant up dc01` / `vagrant up kali`.

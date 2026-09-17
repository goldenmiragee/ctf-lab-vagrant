# Known issues & platform caveats

Honest notes on the rough edges. Documenting what *doesn't* build cleanly is part of the
methodology — it is more useful to a reviewer than pretending everything is frictionless.

## VirtualBox 7.2

- **Very new release.** Some community Vagrant boxes were published against VirtualBox 6.x/7.0
  and occasionally emit guest-additions or shared-folder warnings on 7.2. These are usually
  non-fatal; the box still boots. If a box refuses to import, check for an updated box version.
- **Host-only network range.** VirtualBox restricts host-only networks to
  `192.168.56.0/21` by default (configured in `%HOMEDRIVE%%HOMEPATH%\.VirtualBox\vbox networks`
  / `/etc/vbox/networks.conf`). This lab uses `192.168.56.0/24`, which is allowed by default.
  If you change the subnet, you may need to add it to that allow-list.
- **`VBoxManage` not on PATH.** On Windows the installer often does not add
  `C:\Program Files\Oracle\VirtualBox\` to `PATH`. Vagrant still finds VirtualBox via the
  registry, so this only matters if you call `VBoxManage` directly.

## Windows AD (`dc01`) — Phase 3

- The `windows_2019` box is **large (~10+ GB)** and slow to import; first `vagrant up` can take
  a long time.
- WinRM-based provisioning on VirtualBox 7.2 is **timing-sensitive**. **Observed in this build:**
  the box downloads and boots, WinRM is assigned, and provisioning *starts*, but the WinRM
  `init_auth` (negotiate) call then times out — reproduced across three attempts (initial
  `up`, wait + `up`, wait + `provision`). **Deeper diagnosis:** after a full boot, the WinRM
  TCP port (host-forwarded `5985`) *accepts* connections, but the WSMan HTTP endpoint does
  **not** respond — a `POST /wsman` times out with no reply (not even the expected `401`). So
  the listener is stalled; this is a box-vs-VirtualBox-7.2 incompatibility, **not** a
  timeout-tuning issue (raising timeouts or switching to plaintext/basic auth won't revive a
  non-responsive HTTP layer). The box vintage (`StefanScherer/windows_2019` v2021.05.15)
  predates VirtualBox 7.2 and its guest additions/WinRM stack lag behind.
  **Real fixes:** use a **newer Windows box** rebuilt for VirtualBox 7.x, or **provision AD
  manually** by opening the VM console / RDP and running `provision/dc01.ps1` inside the guest.
  The `Vagrantfile` already raises `winrm.timeout`/`boot_timeout` in case a given host is only
  borderline. This is the fragile piece of the lab.
- Promoting the domain controller **reboots** the guest mid-provision. This is expected; give
  it time.
- If the DC proves unstable on this VirtualBox version, that outcome will be recorded in the
  Testing Log rather than hidden — an honest "this didn't work reliably and here's why" is a
  legitimate portfolio result.

## Metasploitable (`metasploitable`) — Phase 2

Verified on VirtualBox 7.2 (box `rapid7/metasploitable3-ub1404` v0.1.12):

- **The box needs its built-in `vagrant`/`vagrant` credentials with key insertion disabled**
  (`insert_key = false`), otherwise `vagrant up` loops on `Authentication failure`. This is
  configured in the `Vagrantfile`. A side effect: `vagrant ssh -c` won't work for this box
  (password auth) — use interactive `vagrant ssh` or `ssh vagrant@192.168.56.20`.
- The **first boot is slow** and may exceed the SSH-wait timeout; the VM keeps booting. A
  `vagrant reload metasploitable` (or a second `vagrant up`) finishes networking.
- Once up, it is reachable on the host-only net at **192.168.56.20** with ports **21, 22, 80,
  3306** open (confirmed). It runs **ProFTPD 1.3.5** and **Apache 2.4.7**.
- ✅ **Flags aligned to this box:** the 11 `MSF_*` flags are authored for **Metasploitable3-ub1404**
  and reflect its real services — ProFTPD 1.3.5 (CVE-2015-3306 / `mod_copy`), Apache 2.4.7, a
  Drupal 7 site under `/drupal` (Drupalgeddon2, CVE-2018-7600), `phpMyAdmin`, a SQL-injectable
  `payroll_app.php`, MySQL, and Samba on 445. Five box-observable answers (FTP banner, Apache
  version, `payroll_app.php`, `phpmyadmin`, SMB port 445) were verified to match the scoreboard;
  the rest are the correct CVEs/technique names for those confirmed services.
- The image is intentionally unpatched — never expose it beyond the host-only net.

## Juice Shop / DVWA

- Juice Shop is provisioned via Docker; the first boot pulls the image, which needs the box to
  reach the internet **once at build time**. After provisioning it runs fully offline. (Only
  the target's build-time package/image fetches touch the internet, never the vulnerable
  surface at runtime.)
- DVWA requires setting the security level (Low/Medium/High) via its cookie/session to match
  the difficulty a given flag expects; each flag question notes the intended level.

## Scoreboard

- Binds to `127.0.0.1` only and has no authentication — intentional for a local lab. Do not
  change the bind address to `0.0.0.0`.
- Progress lives in browser `localStorage`; clearing site data resets your progress (the flags
  themselves are unaffected).

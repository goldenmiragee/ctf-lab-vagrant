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
- WinRM-based provisioning on VirtualBox 7.2 can be **timing-sensitive**; a provisioning step
  may need a retry (`vagrant provision dc01`).
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
- ⚠️ **Flag-set mismatch (action needed):** the 11 `MSF_*` flags were authored with classic
  **Metasploitable2** semantics (vsftpd 2.3.4, UnrealIRCd 6667, Samba usermap CVE-2007-2447,
  distccd, Java RMI, Tomcat). This Vagrant box is **Metasploitable3-ub1404**, which exposes a
  *different* service set (e.g. ProFTPD 1.3.5 → CVE-2015-3306, and typically ElasticSearch,
  Drupal, phpMyAdmin, Jenkins). Before relying on the `MSF_*` flags, either **(a)** re-author
  them to this box's real services, or **(b)** supply an actual Metasploitable2 image. Tracked
  as an open item; these flags are **not** marked verified.
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

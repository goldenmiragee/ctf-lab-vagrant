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

- Some legacy services (e.g. Samba usermap) can be flaky to trigger depending on the box image
  and networking mode; workarounds are noted in the relevant walkthrough.
- The image is intentionally ancient and unpatched — never expose it beyond the host-only net.

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

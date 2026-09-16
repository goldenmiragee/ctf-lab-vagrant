# Walkthrough — `ubuntu-server` (192.168.56.30)

> 🚧 **Work in progress.** Methodology and intended paths are outlined; solved-flag notes and
> screenshots are added as the lab is run end-to-end. No plaintext flags here (see the
> [no-spoiler policy](README.md#no-spoiler-policy)).

`ubuntu-server` is a **planted** target: provisioning creates the vulnerabilities and writes
`FLAG{...}` tokens. Focus areas are **information disclosure**, **service misconfiguration**,
and **Linux privilege escalation**.

## Recommended workflow

1. **Enumerate.** `nmap -sV -p- 192.168.56.30` to map services (HTTP, SSH, custom banner on
   8081, admin API on 8082, NFS, MySQL).
2. **Web & info-disclosure (Basic).** Browse the web root; check `robots.txt`, `/backup/`, an
   exposed `.git/` directory, MOTD on SSH login, `/opt/backup/`, cron files under
   `/etc/cron.d`, and shell history for the `deploy` user.
3. **Get a foothold.** The `deploy` account uses weak/default SSH credentials.
4. **Privilege escalation (Medium).** Enumerate with `sudo -l`, `find / -perm -4000`,
   `getcap -r /`, and inspect cron. Expect a GTFOBins-style sudo escape, a SUID PATH hijack, a
   world-writable root cron script, a `cap_dac_read_search`/`setuid` capability, an
   empty-password MySQL root, and an NFS `no_root_squash` export.
5. **Privilege escalation (Hard).** Look for a writable `systemd` unit, `LD_PRELOAD`
   preservation in sudoers, `docker`-group membership (root-equivalent), a leaked-but-valid
   API token in git history usable against the `:8082` admin API, a `tar` wildcard-injection
   cron, and reused credentials that **pivot to `ubuntu-client`**.

## Testing log (this box)

| Flag id   | Technique                       | Result     | Notes                                  |
|-----------|---------------------------------|:----------:|----------------------------------------|
| SRV_B01   | Exposed web-root file           | _planned_  |                                        |
| SRV_M01   | `sudo` GTFOBins escape          | _planned_  |                                        |
| SRV_M02   | SUID PATH hijack                | _planned_  |                                        |
| SRV_H03   | `docker` group → host root      | _planned_  |                                        |
| SRV_H06   | Credential reuse → pivot        | _planned_  | Confirms `ubuntu-client` reachability  |

_Fill Result with ✅ / ⚠️ / ❌ and notes as each is executed._

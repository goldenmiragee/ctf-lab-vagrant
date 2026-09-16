# Remediation notes

For every vulnerability class in the lab, the defensive fix. Understanding the patch is as
important as understanding the exploit — this is the half most CTF write-ups skip.

## Web application

| Vulnerability            | Fix                                                                                  |
|--------------------------|--------------------------------------------------------------------------------------|
| SQL injection            | Parameterized queries / prepared statements; ORM with bound params; least-priv DB user |
| Reflected/stored XSS     | Context-aware output encoding; Content-Security-Policy; validate input; `HttpOnly` cookies |
| DOM XSS                  | Avoid `innerHTML`/`document.write`; use `textContent`; sanitize with a vetted library |
| CSRF                     | Anti-CSRF tokens bound to the session; `SameSite` cookies; no state change via `GET`  |
| Command injection        | Never pass user input to a shell; use exec APIs with argument arrays; allow-lists      |
| File inclusion (LFI/RFI) | Whitelist includable files; disable `allow_url_include`; canonicalize & confine paths |
| Insecure file upload     | Validate content/magic bytes server-side; store outside web root; never execute uploads |
| IDOR / broken access ctl | Enforce object-level authorization on every request; never trust client-side guards    |
| JWT `alg:none` / downgrade | Pin allowed algorithms server-side; reject `none`; verify signatures                |
| SSRF                     | Allow-list outbound URLs; block internal ranges/metadata IPs; never fetch raw user URLs |
| XXE                      | Disable DTD / external-entity resolution in the XML parser                             |
| NoSQL injection          | Sanitize operators (`$gt`, `$ne`); strict schemas; typed queries                       |
| Weak password hashing    | Slow, salted KDFs (bcrypt / scrypt / argon2); never MD5/SHA-1 for passwords            |

## Linux privilege escalation

| Vulnerability            | Fix                                                                                  |
|--------------------------|--------------------------------------------------------------------------------------|
| Dangerous `sudo` rules   | Grant only specific safe commands; audit `NOPASSWD` entries against GTFOBins          |
| `sudo` env preservation  | Set `secure_path`; never `env_keep` `PATH` / `LD_PRELOAD` / `LD_LIBRARY_PATH`         |
| SUID custom binaries     | Avoid SUID; use absolute paths; drop privileges early; validate all input             |
| SUID PATH hijack         | Call binaries by absolute path; sanitize `PATH` in privileged code                    |
| World-writable cron/script | Root cron scripts must be root-owned, `chmod 700`; no writable dirs in root's `PATH`  |
| `tar`/wildcard injection | Avoid shell wildcards in privileged scripts; explicit file lists; use `--`            |
| Linux capabilities abuse | Remove unnecessary file capabilities; audit with `getcap -r /`                        |
| `docker` group membership| Treat as root-equivalent; use rootless Docker; restrict the socket                    |
| Writable `systemd` unit  | Lock unit-file permissions; restrict who can edit/restart services                    |
| polkit rule misconfig    | Review custom rules; least privilege for actions                                      |
| TOCTOU race              | `O_NOFOLLOW`, `mkstemp`, operate on the fd (`openat`) not the path                    |
| Format-string bug        | Never pass user input as a format string; compile with `FORTIFY_SOURCE`               |
| `sudo` token/ptrace      | `timestamp_timeout=0` for sensitive users; `kernel.yama.ptrace_scope=2`               |
| User-namespace abuse     | Disable unprivileged user namespaces if unused; validate uid mapping in setuid code   |

## Services / network

| Vulnerability            | Fix                                                                                  |
|--------------------------|--------------------------------------------------------------------------------------|
| Default / empty creds    | Change defaults on deploy; enforce password policy; bind DBs to localhost             |
| Backdoored packages      | Patch/replace; verify software supply chain; monitor for known-bad daemons            |
| Legacy r-services        | Remove `rlogin`/`rsh`; use SSH with key auth                                          |
| Exposed admin interfaces | Restrict to localhost/VPN; strong creds; network segmentation                         |
| Version-disclosing banners | Suppress banners; expose only necessary ports                                       |
| NFS `no_root_squash`     | Use `root_squash`; restrict exports to specific hosts; prefer Kerberos-backed NFSv4   |
| Weak archive crypto      | Strong passphrases + authenticated encryption (age/gpg), not zip crypto               |

## Active Directory

| Vulnerability            | Fix                                                                                  |
|--------------------------|--------------------------------------------------------------------------------------|
| AS-REP roasting          | Require Kerberos pre-authentication on all accounts; strong passwords                 |
| Kerberoasting            | Long random (g)MSA passwords; monitor anomalous SPN ticket requests                   |
| DCSync                   | Restrict replication rights (`DS-Replication-Get-Changes*`); monitor DRSUAPI          |
| Golden ticket            | Rotate `KRBTGT` twice periodically; protect Tier-0; detect anomalous TGTs             |
| Pass-the-hash            | Credential Guard; restrict local admin (LAPS); enable SMB signing                     |
| Unconstrained delegation | Avoid it; use constrained/RBCD; mark privileged accounts "sensitive"                  |
| Dangerous ACLs           | Audit with BloodHound; remove excessive delegated rights (`GenericAll`/`GenericWrite`)|

## Information disclosure (general)

Keep secrets out of web roots, MOTD/banners, logs, shell history, git history, EXIF
metadata, and world-readable files. Scan repos with tools like `gitleaks`; strip metadata
before sharing files; `chmod 600` credential files; rotate and revoke leaked tokens
immediately.

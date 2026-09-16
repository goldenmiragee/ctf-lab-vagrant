# Walkthroughs

Per-machine, per-level notes on the intended solution path — methodology, tooling, and the
"what worked / what didn't" story. These are written **as I actually run the lab**, so they
fill in over time.

## No-spoiler policy

These walkthroughs describe **approach and methodology**, not copy-paste flag values. The
actual flags stay out of the repo (see the [flag system](../architecture.md#the-flag-system)).
If you want the plaintext answers for self-grading, generate them locally with your private
`flags_source.py` — they land in the git-ignored `answers-key.md`.

## Index

| Machine          | Status        | File                                        |
|------------------|---------------|---------------------------------------------|
| `ubuntu-server`  | 🚧 WIP        | [ubuntu-server.md](ubuntu-server.md)        |
| `ubuntu-client`  | 🚧 planned    | _to be added_                               |
| `dvwa`           | 🚧 planned    | _to be added_                               |
| `juiceshop`      | 🚧 planned    | _to be added_                               |
| `metasploitable` | 🚧 Phase 2    | _to be added_                               |
| `dc01`           | 🚧 Phase 3    | _to be added_                               |

## Suggested toolkit

Recon & scanning: `nmap`, `netcat`, `gobuster`/`ffuf`.
Web: Burp Suite / OWASP ZAP, browser devtools, `sqlmap`.
Privesc enumeration: `linpeas`, `pspy`, `sudo -l`, `getcap`, GTFOBins.
Cracking: `john`, `hashcat`, `fcrackzip`, the `rockyou` wordlist.
Active Directory: `impacket`, `BloodHound`, `Rubeus`, `CrackMapExec`.

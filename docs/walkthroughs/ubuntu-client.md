# Walkthrough — `ubuntu-client` (192.168.56.31)

A **planted** workstation focused on **local privilege escalation** and **information
disclosure**. All 20 `CLI_*` flags were verified captured on the live VM. No plaintext flags
here (see the [no-spoiler policy](README.md#no-spoiler-policy)).

## Foothold

Log in as **alice** (weak password `password123`). From there, enumerate thoroughly with
`sudo -l`, `id`, `find / -perm -4000 2>/dev/null`, `getcap -r / 2>/dev/null`, `crontab -l`,
and a tool like `linpeas`.

## Basic — information disclosure

- **Desktop note** in `~/Desktop/`, and a flag in alice's home.
- **EXIF metadata**: `exiftool ~/Pictures/vacation.jpg` (check the Comment tag).
- **base64** in a `~/.config` dotfile — decode the `backup_key`.
- **Whitespace steganography**: a "blank" file in `/tmp` — inspect with `cat -A` / `xxd`,
  then map space/tab to bits.
- **Plaintext browser creds**, a **world-readable hidden file at `/`**, and a flag leaked to
  a **log / the journal** (`journalctl | grep FLAG`).

## Medium — local privesc

- **sudo to an editor** (GTFOBins shell escape) → root.
- A **group-writable root script** run by cron (alice ∈ `devs`).
- A **world-readable private SSH key** for `bob` → `ssh bob@localhost`.
- **bob's cron** runs a script alice can edit.
- A **readable `/etc/shadow` backup** — crack bob's hash (`john`/`hashcat` + rockyou). The
  recovered *password* is the answer (verified: it cracks to the seeded value).
- A **polkit rule** granting `devs` a privileged action; and a **writable dir in root's cron
  `PATH`**.

## Hard

- Unprivileged **user-namespace** primitive; a real **TOCTOU** race in a setuid helper; a
  real **format-string** setuid binary that holds the flag in memory; a **sudo-token/ptrace**
  scenario; and an **XOR-split** flag reconstructed from `/opt/parts/{a,b,c}.bin`.

## Testing log (this box)

| Flag id  | Technique                        | Result | Notes                                  |
|----------|----------------------------------|:------:|----------------------------------------|
| CLI_B03  | EXIF comment extraction          | ✅     | `exiftool -Comment` value validates     |
| CLI_B04  | base64 dotfile decode            | ✅     | decoded value hash-matches              |
| CLI_B05  | whitespace stego decode          | ✅     | reconstructed value validates           |
| CLI_M03  | readable private key → `bob`     | ✅     | key perms loosened as designed          |
| CLI_M05  | `/etc/shadow` backup crack       | ✅     | hash cracks to the seeded password      |
| CLI_H05  | XOR-split reconstruction         | ✅     | `a ^ b ^ c` yields the flag             |
| SRV_H06  | pivot flag (from `ubuntu-server`)| ✅     | reachable via reused creds              |

_All 20 `CLI_*` planted flags verified end-to-end._

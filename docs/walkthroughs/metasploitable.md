# Walkthrough — `metasploitable` (192.168.56.20)

Prebuilt `rapid7/metasploitable3-ub1404`. **Derived** flags — service exploitation. Verified
reachable at `192.168.56.20` (ports 21/22/80/3306). Access it with `vagrant ssh` or
`ssh vagrant@192.168.56.20` (password `vagrant`).

## Enumeration

`nmap -sV 192.168.56.20`. Confirmed services: **ProFTPD 1.3.5** (21), **OpenSSH 6.6.1** (22),
**Apache 2.4.7** (80) hosting **Drupal 7** (`/drupal`), **phpMyAdmin** (`/phpmyadmin`) and a
SQL-injectable **`payroll_app.php`**, **MySQL** (3306), and **Samba** (445).

## Basic

- **FTP banner** on 21 → ProFTPD name+version.
- **Apache version** from the `Server` header.
- **MySQL** default superuser account.
- **`payroll_app.php`** — the SQL-injectable page name.

## Medium

- **ProFTPD 1.3.5 `mod_copy` RCE** → its CVE (2015).
- **Drupalgeddon2** on `/drupal` → its CVE (2018).
- **phpMyAdmin** exposed admin path.

## Hard

- The ProFTPD **module** providing `SITE CPFR/CPTO`.
- Post-exploitation: which file holds the crackable Linux hashes.
- **Samba** SMB port for lateral movement.
- The Drupal RCE's one-word nickname.

## Tools

`nmap`, Metasploit (`exploit/unix/ftp/proftpd_modcopy_exec`,
`exploit/unix/webapp/drupal_drupalgeddon2`), `sqlmap`, `hydra`.

## Testing log (this box)

| Flag id  | Technique                     | Result | Notes                                  |
|----------|-------------------------------|:------:|----------------------------------------|
| MSF_B01  | FTP banner (ProFTPD 1.3.5)    | ✅     | banner grab validates                   |
| MSF_B02  | Apache version (2.4.7)        | ✅     | `Server` header validates               |
| MSF_B04  | `payroll_app.php` present     | ✅     | reachable (HTTP 200)                    |
| MSF_M03  | phpMyAdmin path               | ✅     | reachable (HTTP 200)                    |
| MSF_H03  | Samba SMB port 445            | ✅     | port open                               |
| MSF_M01/M02/H01/H04 | ProFTPD/Drupal CVEs | ✅ (fact) | CVEs match the confirmed services  |

> ⚠️ Note: this box needs `insert_key = false` + `vagrant/vagrant` creds (set in the
> `Vagrantfile`), and a slow first boot — see [known-issues](../known-issues.md).

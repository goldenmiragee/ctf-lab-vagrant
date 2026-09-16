# Architecture

## Network diagram

The entire lab lives on a single VirtualBox **host-only** network,
`192.168.56.0/24`. There is **no bridged/NAT adapter on the vulnerable targets**, so the
deliberately-broken machines can talk to each other and to your host, but never to your
LAN or the internet.

```
                      ┌────────────────────────────────────────────────┐
   Your host          │        VirtualBox host-only network              │
   (Windows) ─────────┤            192.168.56.0/24  (vboxnet0)           │
        │             │                                                  │
   127.0.0.1:<port>   │   .10  kali            (attacker workstation)    │
   scoreboard app     │   .20  metasploitable  (service exploitation)    │
                      │   .21  dvwa            (classic web app vulns)   │
                      │   .22  juiceshop       (modern web / OWASP Top10)│
                      │   .30  ubuntu-server   (services + privesc)      │
                      │   .31  ubuntu-client   (local privesc/misconfig) │
                      │   .40  dc01            (Windows AD DC)           │
                      └────────────────────────────────────────────────┘
                         no route to the internet from the targets
```

The **scoreboard** is not a VM — it runs on your host from `scoreboard/server.py`, binds to
`127.0.0.1` only, and is where you submit captured flags.

## Design decisions

- **Host-only, not bridged.** Intentionally vulnerable machines must never be reachable from
  a real network. Host-only gives inter-VM connectivity (needed for pivoting and AD attacks)
  while staying isolated.
- **Infrastructure-as-code.** One `Vagrantfile` defines every VM. `vagrant up <name>` builds
  a box; `vagrant destroy -f <name>` resets it. Reproducibility is the whole point.
- **Static IPs.** Each machine gets a fixed `192.168.56.x` so flag questions, walkthroughs,
  and pivots can reference stable addresses.
- **Phased boxes.** The `Vagrantfile` defines all machines, but you bring them up on demand.
  The heavy Windows DC and Metasploitable images are not required for Phase 1, so the lab is
  usable within minutes rather than hours.
- **Deterministic flags.** Planted flags are written from `provision/flags.env` (generated
  from the private `flags_source.py`), so every rebuild plants the same values and the
  scoreboard hashes stay valid. See [the flag system](#the-flag-system) below.
- **Least surprise for cloners.** With no private `flags_source.py`, `generate.py` falls back
  to the committed `flags_source.example.py`, so `vagrant up` + scoreboard still work with
  placeholder flags.

## The flag system

```
flags_source.py (PRIVATE)  ──generate.py──▶  scoreboard/flags.json  (PUBLIC: hashes only)
        │                                     answers-key.md        (PRIVATE)
        └── fallback: flags_source.example.py provision/flags.env   (PRIVATE: planted values)
```

- **Planted** flags (custom Ubuntu boxes): provisioning writes a `FLAG{...}` token to a file
  / account / service the player must discover or exploit.
- **Derived** flags (DVWA / Juice Shop / Metasploitable / DC): the answer is a value the
  player extracts by exploiting the target (a password, hash, CVE id, or config value).

Validation is **client-side**: the browser SHA-256-hashes the submitted answer
(`sha256(answer.strip())`) and compares it to the stored hash. This is a learning aid, not a
tamper-proof competition scorer — the design goal is guided practice with immediate feedback
and sequential unlocking, not anti-cheat.

## Phasing

| Phase | Machines                                             | Why                                   |
|-------|------------------------------------------------------|---------------------------------------|
| 1     | `ubuntu-server`, `ubuntu-client`, `dvwa`, `juiceshop`| Fast to build; covers most of the 90 flags |
| 2     | `metasploitable`                                     | Classic service exploitation          |
| 3     | `dc01` (Windows AD)                                   | Heaviest image; done last             |

`kali` is optional and not brought up by default (large download); use your existing Kali VM
or add it when needed. See [known-issues.md](known-issues.md) for platform caveats.

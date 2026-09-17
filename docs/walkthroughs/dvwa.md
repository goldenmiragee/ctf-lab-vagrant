# Walkthrough — `dvwa` (192.168.56.21)

Damn Vulnerable Web App on Apache + PHP + MariaDB. **Derived** flags — you extract values by
exploiting the app. Verified reachable (HTTP 200, login page renders).

## Setup

Browse `http://192.168.56.21/` → log in with **admin / password** → click **Create / Reset
Database** → set the **DVWA Security** level (cookie) to match each flag's stated difficulty.

## Basic (Low security)

- **Default creds** — the infamous admin password.
- **SQLi** in the ID field (`%' OR '1'='1`) to dump users; the admin hash is an MD5.
- **Reflected XSS** — a `<script>` payload in the name field.
- **Command injection** — append `; cat /etc/passwd` to the ping input.
- **File inclusion (LFI)** — the vulnerable `page` parameter.
- **CSRF** — the password-change form that changes state via `GET`.

## Medium

- **SQLi** where the id is sent via POST and numeric — no quotes needed.
- **Stored XSS** in the guestbook — bypass the client-side length limit with devtools.
- **File upload** — forge the `Content-Type` to upload a PHP webshell.
- **Command injection** — a still-working chaining operator when `;`/`&&` are filtered.
- **CSRF / session** — the anti-CSRF token cookie name used at higher levels.

## Hard

- **Blind SQLi** — boolean/time-based (or `sqlmap`) to extract the DB version.
- **DOM XSS** — the JS sink abusing the URL fragment.
- **CSRF (token-bound)** — what must be stolen/predicted to forge a request.
- **Upload → RCE** — chain the High upload bypass to run a command as the web user.

## Tools

Burp Suite / OWASP ZAP, browser devtools, `sqlmap`, a simple PHP webshell.

## Testing log (this box)

| Area              | Result | Notes                                            |
|-------------------|:------:|--------------------------------------------------|
| Service up        | ✅     | HTTP 200; login page renders after DB fix        |
| Default creds     | ✅     | `admin`/`password` (answer hash verified)         |
| Exploit flags     | _manual_ | Require hands-on exploitation per level         |

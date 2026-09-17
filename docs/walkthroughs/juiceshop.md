# Walkthrough — `juiceshop` (192.168.56.22)

OWASP Juice Shop (Dockerised). **Derived** flags — modern OWASP Top 10. Verified reachable
(HTTP 200; container healthy, `:80→:3000`).

## Setup

Browse `http://192.168.56.22/`. First, **find the hidden Score Board** (guess the `#/` route
or read the JS bundle) — it lists every built-in challenge.

## Basic

- **Discovery** — the Score Board route.
- **Error handling** — provoke a 500 to leak the Node web framework.
- **Sensitive data** — the static folder that lists confidential docs.

## Medium

- **SQLi auth bypass** in the login email field (`' OR 1=1--`).
- **Broken auth** — the guessable security-question password reset.
- **JWT** — the `alg` downgrade that forges tokens.
- **IDOR** — change the identifier in the basket API path.

## Hard

- **NoSQL injection** against the review/order features (document store).
- **XXE** via a crafted XML upload (external entity).
- **Insecure deserialization / RCE** via a functionality that evaluates user code.
- **SSRF** via the profile-image-URL field.
- **Broken access control** — reach the admin SPA route.
- **Weak crypto** — the fast, unsalted password hash in use.

## Tools

Browser devtools, Burp Suite, `jwt_tool`, the built-in Score Board to track progress.

## Testing log (this box)

| Area          | Result | Notes                                     |
|---------------|:------:|-------------------------------------------|
| Service up    | ✅     | HTTP 200; Docker container running         |
| Exploit flags | _manual_ | Require hands-on exploitation           |

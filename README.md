# NodeJS App

A deliberately vulnerable Node.js application used to demo [OWASP Dependency-Track](https://dependencytrack.org/)  an open-source platform for tracking and managing vulnerabilities in third-party dependencies.

## What this app does

A simple Express REST API with three endpoints:

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Returns app name and version |
| `/users` | GET | Returns a sorted list of users |
| `/login` | POST | Accepts a username and returns a signed JWT token |

## Running the app

```bash
npm install
npm start
# Server runs on http://localhost:3000
```

## Vulnerable dependencies

The app intentionally uses outdated package versions with known CVEs to demonstrate Dependency-Track's detection capabilities.

| Package | Version | CVE | Severity | Description |
|---|---|---|---|---|
| `ejs` | 2.7.4 | CVE-2022-29078 | Critical | Server-side template injection leading to RCE |
| `minimist` | 1.2.5 | CVE-2021-44906 | Critical | Prototype pollution |
| `jsonwebtoken` | 8.5.1 | CVE-2022-23539 | High | Weak key type validation — auth bypass |
| `moment` | 2.29.1 | CVE-2022-24785 | High | Path traversal via locale input |
| `node-fetch` | 2.6.0 | CVE-2022-0235 | High | Exposure of sensitive headers on redirect |
| `serialize-javascript` | 2.1.1 | CVE-2020-7660 | High | XSS via regex serialization |
| `express` | 4.18.2 | Multiple | Medium | Transitive dependency vulnerabilities |

---

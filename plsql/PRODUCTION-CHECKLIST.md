# PL/SQL Production Checklist — Packages & Permissions

This document identifies every database privilege, pre-installed component, and DBA action required before deploying this code to a production Oracle environment.

---

## Script Execution Order & Required Roles

| # | File | Must Run As |
|---|------|-------------|
| 1 | `upstream/01-setup-oracle-acl.sql` | **SYS or SYSTEM** |
| 2 | `downstream/01-setup-oracle-acl.sql` | **SYS** |
| 3 | `upstream/02-upstream-service.sql` | OWNER schema |
| 4 | `downstream/02-downstream-service.sql` | OWNER schema |
| 5 | `downstream/03-setup-ords.sql` | OWNER schema (ORDS must be installed first) |
| 6 | `upstream/03-run-upstream.sql` | OWNER schema |
| 7 | `downstream/04-test-downstream.sql` | OWNER schema |

---

## Required DBA Actions

### 1. Run ACL Setup Scripts as SYS / SYSTEM

**Files:** `upstream/01-setup-oracle-acl.sql`, `downstream/01-setup-oracle-acl.sql`

Both scripts call `DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE()`, which controls which database schemas are allowed to make outbound TCP/HTTP connections. This package can only be executed by SYS or SYSTEM — a regular application schema cannot call it.

> **Action:** A DBA must run these two scripts under a privileged account before any application code is executed.

---

### 2. Grant EXECUTE on UTL_HTTP

**Files:** `upstream/02-upstream-service.sql`, `downstream/02-downstream-service.sql`

`UTL_HTTP` is used to make HTTP calls to HashiCorp Vault and to the downstream service. By default Oracle does not grant this package to application schemas.

```sql
GRANT EXECUTE ON UTL_HTTP TO OWNER;
```

> **Action:** DBA must run the above GRANT before the procedures are called.

---

### 3. Update ACL Host Entries for Production

The ACL setup scripts currently allow outbound connections to `127.0.0.1` and `localhost` (development defaults). These must be updated to the real hostnames/IPs before the scripts are run in production.

| Placeholder (dev) | Connects to | Replace with |
|---|---|---|
| `127.0.0.1` / `localhost` | HashiCorp Vault (port 8200) | Production Vault server hostname or IP |
| `127.0.0.1` / `localhost` | Downstream ORDS service (port 3001) | Production service hostname or IP |

> **Action:** DBA and developer must agree on production hostnames and update the `host =>` values in both ACL scripts before running them.

---

### 4. Confirm ORDS Is Installed

**File:** `downstream/03-setup-ords.sql`

This script uses the following packages which only exist if **Oracle REST Data Services (ORDS)** is installed and configured on the database:

| Package | Used for |
|---|---|
| `ORDS.ENABLE_SCHEMA()` | Exposing the OWNER schema via REST |
| `ORDS.DEFINE_MODULE()` | Creating the REST module |
| `ORDS.DEFINE_TEMPLATE()` | Defining the URL pattern |
| `ORDS.DEFINE_HANDLER()` | Attaching the PL/SQL block to `GET /api/data` |
| `OWA_UTIL` | Reading request headers, setting HTTP status/content-type |
| `HTP.P()` | Writing the HTTP response body |

> **Action:** DBA must confirm ORDS is installed and accessible from the OWNER schema before running `03-setup-ords.sql`.

> **Note on authentication:** The ORDS endpoint is created with `p_auto_rest_auth => FALSE`. ORDS itself does **not** enforce authentication — token validation is handled inside the PL/SQL code via Vault. The database team should be aware of this design decision.

---

## Production-Critical Gaps (Beyond Permissions)

### 5. HTTPS and Oracle Wallet Setup

All HTTP calls in the current code use plain `http://` (e.g. `http://127.0.0.1:8200`). In production, Vault must be accessed over HTTPS.

`UTL_HTTP` requires an **Oracle Wallet** containing the Vault server's TLS certificate to establish HTTPS connections. Without this, all outbound calls to Vault will fail or be insecure.

Steps required:
1. DBA creates an Oracle Wallet (`orapki wallet create ...`)
2. DBA imports the Vault server's CA certificate into the wallet
3. Developer adds `UTL_HTTP.SET_WALLET('file:/path/to/wallet', 'password')` calls to the procedures
4. All URL literals are updated from `http://` to `https://`

> **Action:** DBA sets up the wallet; developer updates the code to reference it.

---

### 6. Remove Hardcoded Credentials

**File:** `upstream/02-upstream-service.sql` — lines 10–11

The AppRole `ROLE_ID` and `SECRET_ID` are currently hardcoded as string literals:

```sql
v_role_id   VARCHAR2(200) := '30917290-3385-4a8d-2b24-a65d0450a9cb';
v_secret_id VARCHAR2(200) := '0521f733-25c4-c67b-ded5-3a7be4c87d1d';
```

PL/SQL source is stored in `DBA_SOURCE` and is visible to any DBA on the database. These credentials must not appear in source code in production.

> **Action (developer):** Move credentials into a secure config table, a protected package variable loaded at startup, or accept them as procedure parameters. Do not deploy to production with literal credentials in the source.

---

### 7. Firewall — Outbound Access from DB Server

The database server itself needs outbound TCP access to reach Vault. This is separate from the Oracle ACL configuration.

| Source | Destination | Port | Protocol |
|---|---|---|---|
| Oracle DB server | Vault server | 8200 | TCP (HTTPS in production) |

> **Action:** Confirm with the network/security team that the firewall permits this outbound connection from the database host.

---

## Summary Checklist

| # | What | Owner | When |
|---|------|-------|------|
| 1 | Run `upstream/01-setup-oracle-acl.sql` as SYS/SYSTEM | DBA | Before any code runs |
| 2 | Run `downstream/01-setup-oracle-acl.sql` as SYS | DBA | Before any code runs |
| 3 | `GRANT EXECUTE ON UTL_HTTP TO OWNER` | DBA | Before procedures are called |
| 4 | Update ACL host entries from `127.0.0.1` to real Vault/service IPs | DBA + Dev | Before running ACL scripts |
| 5 | Confirm ORDS is installed on the database | DBA | Before running `03-setup-ords.sql` |
| 6 | Set up Oracle Wallet for HTTPS calls to Vault | DBA + Dev | Before production go-live |
| 7 | Remove hardcoded `ROLE_ID` / `SECRET_ID` from PL/SQL source | Dev | Before production go-live |
| 8 | Confirm firewall allows DB server → Vault server on port 8200 | Network + DBA | Before production go-live |

# Vault Service-to-Service Auth Demo

Minimal demo showing AppRole authentication with HashiCorp Vault.

## Files

| File | Purpose |
|------|---------|
| `setup-vault.sh` | Configures Vault: enables AppRole, creates policy & role, outputs credentials to `.env` |
| `upstream-service.js` | Logs in with AppRole, gets token, calls downstream with `X-Vault-Token` header |
| `downstream-service.js` | Validates the token with Vault before serving protected data |

## Flow

1. **Upstream service** logs in to Vault using AppRole (`role_id` + `secret_id`)
2. **Vault** returns a client token
3. **Upstream** calls downstream with `X-Vault-Token: <token>` header
4. **Downstream** validates the token by calling Vault's `/v1/auth/token/lookup-self`
5. If valid, downstream serves the protected data

```
┌─────────────────┐     1. AppRole Login       ┌─────────────┐
│ Upstream Service│ ─────────────────────────▶ │    Vault    │
│                 │ ◀───────────────────────── │             │
│                 │     2. Returns Token       │             │
│                 │                            │             │
│                 │     4. Validate Token      │             │
│                 │        ┌──────────────────▶│             │
└────────┬────────┘        │                   └─────────────┘
         │                 │
         │ 3. Request with │
         │ X-Vault-Token   │
         ▼                 │
┌──────────────────┐       │
│Downstream Service│───────┘
│                  │
└──────────────────┘
```

## Quick Start

### 1. Start Vault dev server (separate terminal)
```bash
vault server -dev -dev-root-token-id="root"
```

### 2. Setup Vault
```bash
chmod +x setup-vault.sh
./setup-vault.sh
```

### 3. Start downstream service (separate terminal)
```bash
node downstream-service.js
```

### 4. Run upstream service
```bash
node upstream-service.js
```

## Expected Output

**Upstream service:**
```
=== Upstream Service ===

1. Logging in to Vault with AppRole...
   Got Vault token: hvs.CAESI...

2. Calling downstream service with X-Vault-Token header...
   Response status: 200
   Response body: {"message":"Authenticated successfully!",...}
```

**Downstream service:**
```
=== Downstream Service ===
Listening on http://127.0.0.1:3001
Waiting for requests...

[...] GET /api/data
   Validating token with Vault...
   ✓ Valid token! Policies: default, my-service-policy
```

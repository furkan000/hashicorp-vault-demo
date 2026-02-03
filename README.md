# Vault Service-to-Service Auth Demo

Minimal demo showing AppRole authentication with HashiCorp Vault.

## Flow

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

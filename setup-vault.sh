#!/bin/bash
# Setup script for Vault token-role auth
# Requires: VAULT_ADDR, VAULT_TOKEN, and VAULT_NAMESPACE to be set

if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ] || [ -z "$VAULT_NAMESPACE" ]; then
  echo "Error: VAULT_ADDR, VAULT_TOKEN, and VAULT_NAMESPACE must be set"
  echo "Example:"
  echo "  export VAULT_ADDR=https://vault.example.com"
  echo "  export VAULT_TOKEN=root"
  echo "  export VAULT_NAMESPACE=my-namespace"
  exit 1
fi

echo "=== Setting up Vault Token Role ==="
echo "Namespace: $VAULT_NAMESPACE"

# Create a policy that allows reading secrets
vault policy write -namespace="$VAULT_NAMESPACE" my-service-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF

# Create a token role (upstream will create child tokens via this role)
vault write -namespace="$VAULT_NAMESPACE" auth/token/roles/my-service \
    allowed_policies="my-service-policy" \
    token_ttl=1h \
    token_max_ttl=4h

echo ""
echo "=== Setup Complete ==="
echo "Token role 'my-service' created with policy 'my-service-policy'"
echo ""
echo "Next steps:"
echo "  1. Get a token from the Vault UI"
echo "  2. Update .env with VAULT_TOKEN, VAULT_NAMESPACE, and VAULT_ADDR"
echo "  3. Start downstream: node downstream-service.js"
echo "  4. Run upstream:   node upstream-service.js"

# Create a test secret
vault kv put -namespace="$VAULT_NAMESPACE" secret/myapp/config message="Hello from Vault!"
echo ""
echo "Test secret created at secret/myapp/config"

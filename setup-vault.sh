#!/bin/bash
# Setup script for Vault AppRole auth
# Assumes: vault server -dev is running with VAULT_ADDR=http://127.0.0.1:8200

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

echo "=== Setting up Vault AppRole ==="

# Enable AppRole auth method
vault auth enable approle 2>/dev/null || echo "AppRole already enabled"

# Create a policy that allows reading secrets
vault policy write my-service-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF

# Create an AppRole role
vault write auth/approle/role/my-service \
    token_policies="my-service-policy" \
    token_ttl=1h \
    token_max_ttl=4h

# Get role-id and secret-id
ROLE_ID=$(vault read -field=role_id auth/approle/role/my-service/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/my-service/secret-id)

echo ""
echo "=== Credentials (save these!) ==="
echo "ROLE_ID=$ROLE_ID"
echo "SECRET_ID=$SECRET_ID"

# Write to .env file for the demo
cat > .env <<EOF
VAULT_ADDR=http://127.0.0.1:8200
ROLE_ID=$ROLE_ID
SECRET_ID=$SECRET_ID
EOF

echo ""
echo "Credentials saved to .env"

# Create a test secret
vault kv put secret/myapp/config message="Hello from Vault!"
echo "Test secret created at secret/myapp/config"

// Upstream Service: Creates a child token via token role, calls downstream service
const http = require('http');
const fs = require('fs');

// Load config from .env
const env = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .reduce((acc, line) => {
    const [k, v] = line.split('=');
    if (k && v) acc[k] = v;
    return acc;
  }, {});

const VAULT_ADDR = env.VAULT_ADDR;
const VAULT_TOKEN = env.VAULT_TOKEN;
const VAULT_NAMESPACE = env.VAULT_NAMESPACE;

// Simple HTTP request helper
function request(url, options, body) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const req = http.request({
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname,
      method: options.method || 'GET',
      headers: options.headers || {}
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function main() {
  console.log('=== Upstream Service ===\n');

  if (!VAULT_TOKEN || !VAULT_NAMESPACE) {
    console.error('Error: VAULT_TOKEN and VAULT_NAMESPACE must be set in .env');
    process.exit(1);
  }

  console.log(`1. Using parent token from .env: ${VAULT_TOKEN.substring(0, 10)}...`);

  // Create a child token scoped to the "my-service" token role
  console.log('\n2. Creating child token via token role "my-service"...');
  const createRes = await request(
    `${VAULT_ADDR}/v1/auth/token/create/my-service`,
    {
      method: 'POST',
      headers: {
        'X-Vault-Token': VAULT_TOKEN,
        'X-Vault-Namespace': VAULT_NAMESPACE,
        'Content-Type': 'application/json'
      }
    },
    JSON.stringify({})
  );

  if (createRes.status !== 200) {
    console.error(`   Error creating child token: ${createRes.status}`);
    console.error(`   ${createRes.body}`);
    process.exit(1);
  }

  const tokenData = JSON.parse(createRes.body);
  const childToken = tokenData.auth.client_token;
  console.log(`   Got child token: ${childToken.substring(0, 10)}...`);
  console.log(`   Policies: ${tokenData.auth.policies.join(', ')}`);

  // Call downstream service with the CHILD token (not the parent)
  console.log('\n3. Calling downstream service with child token...');
  const downstreamRes = await request('http://127.0.0.1:3001/api/data', {
    method: 'GET',
    headers: { 'X-Vault-Token': childToken }
  });

  console.log(`   Response status: ${downstreamRes.status}`);
  console.log(`   Response body: ${downstreamRes.body}`);
}

main().catch(console.error);

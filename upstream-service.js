// Upstream Service: Logs in with AppRole, gets token, calls downstream service
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
const ROLE_ID = env.ROLE_ID;
const SECRET_ID = env.SECRET_ID;

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

  // Step 1: Login to Vault with AppRole
  console.log('1. Logging in to Vault with AppRole...');
  const loginRes = await request(`${VAULT_ADDR}/v1/auth/approle/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, JSON.stringify({ role_id: ROLE_ID, secret_id: SECRET_ID }));

  const loginData = JSON.parse(loginRes.body);
  const vaultToken = loginData.auth.client_token;
  console.log(`   Got Vault token: ${vaultToken}`);

  // Step 2: Call downstream service with token in header
  console.log('\n2. Calling downstream service with X-Vault-Token header...');
  const downstreamRes = await request('http://127.0.0.1:3001/api/data', {
    method: 'GET',
    headers: { 'X-Vault-Token': vaultToken }
  });

  console.log(`   Response status: ${downstreamRes.status}`);
  console.log(`   Response body: ${downstreamRes.body}`);
}

main().catch(console.error);

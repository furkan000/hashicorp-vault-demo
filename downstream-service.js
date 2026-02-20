// Downstream Service: Validates Vault token before serving requests
const http = require('http');
const fs = require('fs');

// Load VAULT_ADDR from .env
const env = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .reduce((acc, line) => {
    const [k, v] = line.split('=');
    if (k && v) acc[k] = v;
    return acc;
  }, {});

const VAULT_ADDR = env.VAULT_ADDR;
const VAULT_NAMESPACE = env.VAULT_NAMESPACE;

// Validate token with Vault
async function validateToken(token) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(`${VAULT_ADDR}/v1/auth/token/lookup-self`);
    const req = http.request({
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname,
      method: 'GET',
      headers: { 'X-Vault-Token': token, 'X-Vault-Namespace': VAULT_NAMESPACE }
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          resolve(null);
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  console.log(`\n[${new Date().toISOString()}] ${req.method} ${req.url}`);

  if (req.url === '/api/data') {
    const vaultToken = req.headers['x-vault-token'];

    if (!vaultToken) {
      console.log('   ✗ No X-Vault-Token header');
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Missing X-Vault-Token header' }));
      return;
    }

    console.log('   Validating token with Vault...');
    const tokenInfo = await validateToken(vaultToken);

    if (!tokenInfo) {
      console.log('   ✗ Invalid token');
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid Vault token' }));
      return;
    }

    console.log(`   ✓ Valid token! Policies: ${tokenInfo.data.policies.join(', ')}`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      message: 'Authenticated successfully!',
      caller_policies: tokenInfo.data.policies,
      secret_data: 'This is protected data only for authenticated services'
    }));
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(3001, () => {
  console.log('=== Downstream Service ===');
  console.log('Listening on http://127.0.0.1:3001');
  console.log('Waiting for requests...');
});

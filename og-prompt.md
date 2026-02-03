Write a minimal end-to-end demo showing service-to-service authentication with HashiCorp Vault.
Assume a dev Vault server is already running.
Include a simple setup script to configure Vault (enable AppRole, create a role and policy).
Use a very minimal implementation using node, keep the code as simple as possible it is not about correct coding practices but about having a hello world of sorts.
Show: AppRole login, receiving a Vault token, calling a downstream service with the token in an HTTP header, and the downstream service validating the token with Vault.

---

Ok now that we have implemented this using node.js. I want for now the upstream service to be programmed using plsql.

I already have a oracle database running
- Host: localhost
- Port: 1521
- Service: ORCLPDB1
- User: owner
- Password: owner_pwd

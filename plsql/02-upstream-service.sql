-- Upstream Service in PL/SQL
-- Logs in to Vault with AppRole, gets token, calls downstream service
--
-- SETUP: Copy ROLE_ID and SECRET_ID from .env file into the variables below

CREATE OR REPLACE PROCEDURE upstream_service_call AS
  -- ╔═══════════════════════════════════════════════════════════════╗
  -- ║ EDIT THESE VALUES (copy from .env after running setup-vault.sh)
  -- ╚═══════════════════════════════════════════════════════════════╝
  v_role_id        VARCHAR2(200) := '30917290-3385-4a8d-2b24-a65d0450a9cb';
  v_secret_id      VARCHAR2(200) := '0521f733-25c4-c67b-ded5-3a7be4c87d1d';
  -- ═══════════════════════════════════════════════════════════════

  v_vault_addr     VARCHAR2(200) := 'http://127.0.0.1:8200';
  v_downstream_url VARCHAR2(200) := 'http://127.0.0.1:3001/api/data';

  v_req            UTL_HTTP.REQ;
  v_res            UTL_HTTP.RESP;
  v_response_body  CLOB;
  v_buffer         VARCHAR2(32767);
  v_vault_token    VARCHAR2(500);
  v_json           JSON_OBJECT_T;
  v_auth           JSON_OBJECT_T;
  v_post_body      VARCHAR2(1000);
BEGIN

  DBMS_OUTPUT.PUT_LINE('=== Upstream Service (PL/SQL) ===');
  DBMS_OUTPUT.PUT_LINE('');

  -------------------------------------------------
  -- Step 1: Login to Vault with AppRole
  -------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('1. Logging in to Vault with AppRole...');

  v_post_body := '{"role_id":"' || v_role_id || '","secret_id":"' || v_secret_id || '"}';

  v_req := UTL_HTTP.BEGIN_REQUEST(
    url => v_vault_addr || '/v1/auth/approle/login',
    method => 'POST'
  );
  UTL_HTTP.SET_HEADER(v_req, 'Content-Type', 'application/json');
  UTL_HTTP.SET_HEADER(v_req, 'Content-Length', LENGTH(v_post_body));
  UTL_HTTP.WRITE_TEXT(v_req, v_post_body);

  v_res := UTL_HTTP.GET_RESPONSE(v_req);

  -- Read response
  v_response_body := '';
  BEGIN
    LOOP
      UTL_HTTP.READ_TEXT(v_res, v_buffer, 32767);
      v_response_body := v_response_body || v_buffer;
    END LOOP;
  EXCEPTION
    WHEN UTL_HTTP.END_OF_BODY THEN
      UTL_HTTP.END_RESPONSE(v_res);
  END;

  -- Check HTTP status
  IF v_res.status_code != 200 THEN
    DBMS_OUTPUT.PUT_LINE('   Vault login failed! Status: ' || v_res.status_code);
    DBMS_OUTPUT.PUT_LINE('   Response: ' || v_response_body);
    RAISE_APPLICATION_ERROR(-20001, 'Vault login failed');
  END IF;

  -- Parse JSON to get token
  v_json := JSON_OBJECT_T.PARSE(v_response_body);
  v_auth := v_json.get_Object('auth');
  IF v_auth IS NULL THEN
    DBMS_OUTPUT.PUT_LINE('   No auth object in response!');
    DBMS_OUTPUT.PUT_LINE('   Response: ' || v_response_body);
    RAISE_APPLICATION_ERROR(-20002, 'No auth in Vault response');
  END IF;
  v_vault_token := v_auth.get_String('client_token');

  DBMS_OUTPUT.PUT_LINE('   Got Vault token: ' || SUBSTR(v_vault_token, 1, 15) || '...');

  -------------------------------------------------
  -- Step 2: Call downstream service with token
  -------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('2. Calling downstream service with X-Vault-Token header...');

  v_req := UTL_HTTP.BEGIN_REQUEST(
    url => v_downstream_url,
    method => 'GET'
  );
  UTL_HTTP.SET_HEADER(v_req, 'X-Vault-Token', v_vault_token);

  v_res := UTL_HTTP.GET_RESPONSE(v_req);

  DBMS_OUTPUT.PUT_LINE('   Response status: ' || v_res.status_code);

  -- Read response
  v_response_body := '';
  BEGIN
    LOOP
      UTL_HTTP.READ_TEXT(v_res, v_buffer, 32767);
      v_response_body := v_response_body || v_buffer;
    END LOOP;
  EXCEPTION
    WHEN UTL_HTTP.END_OF_BODY THEN
      UTL_HTTP.END_RESPONSE(v_res);
  END;

  DBMS_OUTPUT.PUT_LINE('   Response body: ' || v_response_body);

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    RAISE;
END;
/

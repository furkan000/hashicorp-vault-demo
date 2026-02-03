-- Downstream Service in PL/SQL
-- Validates Vault tokens and returns protected data
-- Exposes REST endpoint via ORDS: GET /api/data

CREATE OR REPLACE PACKAGE downstream_service AS
  -- Token cache: stores validated tokens with expiry
  TYPE token_cache_entry IS RECORD (
    policies   VARCHAR2(1000),
    expires_at TIMESTAMP
  );
  TYPE token_cache_type IS TABLE OF token_cache_entry INDEX BY VARCHAR2(500);

  g_token_cache token_cache_type;

  -- Main handler for GET /api/data
  PROCEDURE handle_request(
    p_vault_token IN  VARCHAR2,
    p_status      OUT NUMBER,
    p_response    OUT VARCHAR2
  );

  -- Validate token with Vault (with caching)
  FUNCTION validate_token(p_token IN VARCHAR2) RETURN VARCHAR2;
END downstream_service;
/

CREATE OR REPLACE PACKAGE BODY downstream_service AS
  c_vault_addr CONSTANT VARCHAR2(200) := 'http://127.0.0.1:8200';

  -- Validate token with Vault, returns policies or NULL if invalid
  FUNCTION validate_token(p_token IN VARCHAR2) RETURN VARCHAR2 AS
    v_req           UTL_HTTP.REQ;
    v_res           UTL_HTTP.RESP;
    v_response_body CLOB;
    v_buffer        VARCHAR2(32767);
    v_json          JSON_OBJECT_T;
    v_data          JSON_OBJECT_T;
    v_policies_arr  JSON_ARRAY_T;
    v_policies      VARCHAR2(1000);
    v_ttl           NUMBER;
    v_cached        token_cache_entry;
  BEGIN
    -- Check cache first
    IF g_token_cache.EXISTS(p_token) THEN
      v_cached := g_token_cache(p_token);
      IF v_cached.expires_at > SYSTIMESTAMP THEN
        DBMS_OUTPUT.PUT_LINE('   (using cached token info)');
        RETURN v_cached.policies;
      ELSE
        -- Expired, remove from cache
        g_token_cache.DELETE(p_token);
      END IF;
    END IF;

    -- Call Vault to validate
    DBMS_OUTPUT.PUT_LINE('   Validating token with Vault...');

    v_req := UTL_HTTP.BEGIN_REQUEST(
      url => c_vault_addr || '/v1/auth/token/lookup-self',
      method => 'GET'
    );
    UTL_HTTP.SET_HEADER(v_req, 'X-Vault-Token', p_token);

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

    -- Check status
    IF v_res.status_code != 200 THEN
      DBMS_OUTPUT.PUT_LINE('   Invalid token (status ' || v_res.status_code || ')');
      RETURN NULL;
    END IF;

    -- Parse response
    v_json := JSON_OBJECT_T.PARSE(v_response_body);
    v_data := v_json.get_Object('data');
    v_policies_arr := v_data.get_Array('policies');
    v_ttl := NVL(v_data.get_Number('ttl'), 300);

    -- Build policies string
    v_policies := '';
    FOR i IN 0 .. v_policies_arr.get_size() - 1 LOOP
      IF i > 0 THEN
        v_policies := v_policies || ', ';
      END IF;
      v_policies := v_policies || v_policies_arr.get_String(i);
    END LOOP;

    -- Cache the token
    v_cached.policies := v_policies;
    v_cached.expires_at := SYSTIMESTAMP + NUMTODSINTERVAL(v_ttl, 'SECOND');
    g_token_cache(p_token) := v_cached;

    DBMS_OUTPUT.PUT_LINE('   Valid token! Policies: ' || v_policies);
    RETURN v_policies;

  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('   Error validating token: ' || SQLERRM);
      RETURN NULL;
  END validate_token;

  -- Main request handler
  PROCEDURE handle_request(
    p_vault_token IN  VARCHAR2,
    p_status      OUT NUMBER,
    p_response    OUT VARCHAR2
  ) AS
    v_policies VARCHAR2(1000);
  BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Downstream Service (PL/SQL) ===');
    DBMS_OUTPUT.PUT_LINE('Received request');

    -- Check for token
    IF p_vault_token IS NULL THEN
      DBMS_OUTPUT.PUT_LINE('   No X-Vault-Token provided');
      p_status := 401;
      p_response := '{"error":"Missing X-Vault-Token header"}';
      RETURN;
    END IF;

    -- Validate token
    v_policies := validate_token(p_vault_token);

    IF v_policies IS NULL THEN
      p_status := 403;
      p_response := '{"error":"Invalid Vault token"}';
      RETURN;
    END IF;

    -- Success - return protected data
    p_status := 200;
    p_response := '{"message":"Authenticated successfully!","caller_policies":["' ||
                  REPLACE(v_policies, ', ', '","') ||
                  '"],"secret_data":"This is protected data only for authenticated services"}';
  END handle_request;

END downstream_service;
/

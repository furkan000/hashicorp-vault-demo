-- Test the downstream service directly (without ORDS)
-- This simulates what ORDS would do

SET SERVEROUTPUT ON SIZE UNLIMITED

@02-downstream-service.sql

DECLARE
  v_status   NUMBER;
  v_response VARCHAR2(4000);
  -- ╔═══════════════════════════════════════════════════════════════╗
  -- ║ EDIT THIS: paste a valid Vault token from upstream service
  -- ╚═══════════════════════════════════════════════════════════════╝
  v_test_token VARCHAR2(500) := 'YOUR_VAULT_TOKEN_HERE';
BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test 1: Valid token ---');
  downstream_service.handle_request(
    p_vault_token => v_test_token,
    p_status      => v_status,
    p_response    => v_response
  );
  DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
  DBMS_OUTPUT.PUT_LINE('Response: ' || v_response);

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test 2: No token ---');
  downstream_service.handle_request(
    p_vault_token => NULL,
    p_status      => v_status,
    p_response    => v_response
  );
  DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
  DBMS_OUTPUT.PUT_LINE('Response: ' || v_response);

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test 3: Invalid token ---');
  downstream_service.handle_request(
    p_vault_token => 'invalid-token-12345',
    p_status      => v_status,
    p_response    => v_response
  );
  DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
  DBMS_OUTPUT.PUT_LINE('Response: ' || v_response);

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Test 4: Same valid token again (should use cache) ---');
  downstream_service.handle_request(
    p_vault_token => v_test_token,
    p_status      => v_status,
    p_response    => v_response
  );
  DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
  DBMS_OUTPUT.PUT_LINE('Response: ' || v_response);
END;
/

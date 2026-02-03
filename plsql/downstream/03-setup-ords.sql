-- Setup ORDS REST endpoint for downstream service
-- Run this as OWNER after ORDS is enabled for the schema

-- Enable ORDS for schema (if not already done)
BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'OWNER',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'owner',
    p_auto_rest_auth      => FALSE
  );
  COMMIT;
END;
/

-- Create the REST module
BEGIN
  ORDS.DEFINE_MODULE(
    p_module_name    => 'vault-demo',
    p_base_path      => '/api/',
    p_items_per_page => 25,
    p_status         => 'PUBLISHED',
    p_comments       => 'Vault service-to-service auth demo'
  );

  ORDS.DEFINE_TEMPLATE(
    p_module_name    => 'vault-demo',
    p_pattern        => 'data',
    p_priority       => 0,
    p_etag_type      => 'HASH',
    p_etag_query     => NULL,
    p_comments       => 'Protected data endpoint'
  );

  ORDS.DEFINE_HANDLER(
    p_module_name    => 'vault-demo',
    p_pattern        => 'data',
    p_method         => 'GET',
    p_source_type    => 'plsql/block',
    p_source         => q'[
DECLARE
  v_token    VARCHAR2(500);
  v_status   NUMBER;
  v_response VARCHAR2(4000);
BEGIN
  -- Get token from header
  v_token := OWA_UTIL.GET_CGI_ENV('HTTP_X_VAULT_TOKEN');

  -- Call handler
  downstream_service.handle_request(
    p_vault_token => v_token,
    p_status      => v_status,
    p_response    => v_response
  );

  -- Set response
  OWA_UTIL.STATUS_LINE(v_status);
  OWA_UTIL.MIME_HEADER('application/json', TRUE);
  HTP.P(v_response);
END;
]',
    p_items_per_page => 0
  );

  COMMIT;
END;
/

-- Verify the endpoint is created
SELECT module_name, uri_template, method
FROM user_ords_handlers
WHERE module_name = 'vault-demo';

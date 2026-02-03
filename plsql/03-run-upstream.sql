-- Run the upstream service
-- Make sure you've edited upstream-service.sql with your ROLE_ID and SECRET_ID first!

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

@03-run-upstream.sql

-- Execute the procedure
EXEC upstream_service_call;

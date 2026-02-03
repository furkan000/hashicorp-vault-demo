-- Run this as SYS or SYSTEM to grant network access to OWNER user
-- This allows the OWNER schema to make HTTP calls to localhost

BEGIN
  -- Allow connections to Vault (port 8200) and downstream service (port 3001)
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => '127.0.0.1',
    ace => xs$ace_type(
      privilege_list => xs$name_list('connect', 'resolve'),
      principal_name => 'OWNER',
      principal_type => xs_acl.ptype_db
    )
  );
END;
/

-- Also allow 'localhost' hostname
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'localhost',
    ace => xs$ace_type(
      privilege_list => xs$name_list('connect', 'resolve'),
      principal_name => 'OWNER',
      principal_type => xs_acl.ptype_db
    )
  );
END;
/

COMMIT;

-- Verify ACL setup
SELECT host, lower_port, upper_port, ace_order, principal, privilege
FROM dba_host_aces
WHERE principal = 'OWNER';

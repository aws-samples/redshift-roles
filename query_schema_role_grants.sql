SELECT namespace_name AS schema_name, privilege_type, identity_name AS role_name 
FROM svv_schema_privileges 
WHERE identity_type = 'role' 
ORDER BY 1, 3, 2;

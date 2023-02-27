SELECT owner_name, schema_name, privilege_type, grantee_name AS role_name 
FROM svv_default_privileges 
WHERE grantee_type = 'role' AND schema_name IS NOT NULL 
ORDER BY 1, 2, 4, 3;

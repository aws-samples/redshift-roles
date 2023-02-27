SELECT namespace_name AS schema_name, relation_name AS table_name, privilege_type, identity_name AS role_name 
FROM svv_relation_privileges 
WHERE identity_type = 'role' 
ORDER BY 1, 2, 4, 3;

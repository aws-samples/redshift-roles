SELECT namespace_name AS schema_name, model_name, identity_name AS role_name, privilege_type 
FROM svv_ml_model_privileges 
WHERE identity_type = 'role'
ORDER BY 1, 2, 4, 3;

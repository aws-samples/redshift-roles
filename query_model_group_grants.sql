SELECT namespace_name AS schema_name, model_name, identity_name AS group_name, privilege_type 
FROM svv_ml_model_privileges 
WHERE identity_type = 'group'
ORDER BY 1, 2, 4, 3;

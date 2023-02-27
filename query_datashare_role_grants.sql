SELECT datashare_name, identity_name AS role_name, privilege_type 
FROM svv_datashare_privileges 
WHERE identity_type = 'role' 
ORDER BY 1, 3, 2;

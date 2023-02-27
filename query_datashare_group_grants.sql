SELECT datashare_name, identity_name AS group_name, privilege_type 
FROM svv_datashare_privileges 
WHERE identity_type = 'group' 
ORDER BY 1, 3, 2;

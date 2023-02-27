SELECT language_name, privilege_type, identity_name 
FROM svv_language_privileges 
WHERE identity_type = 'role' AND language_name <> 'mlfunc' 
ORDER BY 1, 3, 2;

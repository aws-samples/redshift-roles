SELECT CASE WHEN l.lanname = 'plpgsql' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS routine_type, f.namespace_name AS schema_name, f.function_name || '(' || f.argument_types || ')', f.privilege_type, f.identity_name AS role_name
FROM svv_function_privileges f
JOIN pg_namespace n ON n.nspname = f.namespace_name
JOIN pg_proc p ON p.proname = f.function_name AND oidvectortypes(p.proargtypes) = f.argument_types AND p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
WHERE f.identity_type = 'role' AND l.lanname <> 'mlfunc'
ORDER BY 1, 2, 3, 5, 4;

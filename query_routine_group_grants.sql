SELECT sub4.routine_type, sub4.nspname AS schema_name, sub4.routine_name, CASE WHEN substring(sub4.grogrant, pos, 1) = 'X' THEN 'EXECUTE' END AS privilege_type, sub4.groname AS group_name
FROM	(
	SELECT sub3.nspname, sub3.routine_name, generate_series(1, length(sub3.grogrant)) AS pos, sub3.routine_type, sub3.groname, sub3.grogrant
	FROM	(
		SELECT sub2.nspname, sub2.proname || '(' || sub2.proargs || ')' AS routine_name, sub2.routine_type, split_part(sub2.acl, '=', 1) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant 
		FROM 	(
			SELECT sub.nspname, sub.proname, sub.routine_type, sub.proargs, split_part(split_part(array_to_string(sub.proacl, ','), ',', i), ' ', 2) AS acl 
			FROM 	(
				SELECT n.nspname, p.proname, CASE WHEN l.lanname = 'plpgsql' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS routine_type, oidvectortypes(p.proargtypes) proargs, generate_series(1, array_upper(p.proacl, 1)) as i, p.proacl 
				FROM pg_proc p 
				JOIN pg_namespace n ON p.pronamespace = n.oid 
				JOIN pg_language l ON p.prolang = l.oid 
				JOIN pg_user u ON p.proowner = u.usesysid 
				WHERE l.lanname <> 'mlfunc' AND u.usename <> 'rdsdb' AND p.proacl IS NOT NULL
				) AS sub 
			WHERE split_part(array_to_string(sub.proacl, ','), ',', i) LIKE 'group %'
			) AS sub2
		) AS sub3
	) AS sub4
ORDER BY 1, 2, 3, 5, 4;

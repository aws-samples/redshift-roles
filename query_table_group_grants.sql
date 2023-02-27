SELECT sub4.nspname AS schema_name, sub4.relname AS table_name, 
CASE 	WHEN substring(sub4.grogrant, pos, 1) = 'a' THEN 'INSERT' 
	WHEN substring(sub4.grogrant, pos, 1) = 'w' THEN 'UPDATE'
	WHEN substring(sub4.grogrant, pos, 1) = 'd' THEN 'DELETE'
	WHEN substring(sub4.grogrant, pos, 1) = 'r' THEN 'SELECT'
	WHEN substring(sub4.grogrant, pos, 1) = 'x' THEN 'REFERENCES'
	WHEN substring(sub4.grogrant, pos, 1) = 't' THEN 'TRIGGER'
	WHEN substring(sub4.grogrant, pos, 1) = 'R' THEN 'RULE' END AS privilege_type, sub4.groname AS group_name
FROM	(
	SELECT sub3.nspname, sub3.relname, generate_series(1, length(sub3.grogrant)) AS pos, sub3.groname, sub3.grogrant
	FROM	(
		SELECT sub2.nspname, sub2.relname, split_part(sub2.acl, '=', 1) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant 
		FROM 	(
			SELECT sub.nspname, sub.relname, split_part(split_part(array_to_string(sub.relacl, ','), ',', i), ' ', 2) AS acl 
			FROM 	(
				SELECT n.nspname, c.relname, generate_series(1, array_upper(c.relacl, 1)) AS i, c.relacl 
				FROM pg_class c 
				JOIN pg_namespace n ON c.relnamespace = n.oid
				) AS sub 
			WHERE split_part(array_to_string(sub.relacl, ','), ',', i) LIKE 'group %'
			) AS sub2
		) AS sub3
	) AS sub4
ORDER BY 1, 2, 4, 3;

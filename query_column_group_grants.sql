SELECT sub4.nspname AS schema_name, sub4.relname AS table_name, sub4.attname AS column_name, 
CASE 	
	WHEN substring(sub4.grogrant, pos, 1) = 'w' THEN 'UPDATE'
	WHEN substring(sub4.grogrant, pos, 1) = 'r' THEN 'SELECT' END AS privilege_type, sub4.groname AS group_name
FROM	(
	SELECT sub3.nspname, sub3.relname, sub3.attname, generate_series(1, length(sub3.grogrant)) AS pos, sub3.groname, sub3.grogrant
	FROM	(
		SELECT sub2.nspname, sub2.relname, sub2.attname, split_part(sub2.acl, '=', 1) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant
		FROM	(
			SELECT sub.nspname, sub.relname, sub.attname, split_part(split_part(array_to_string(sub.attacl, ','), ',', i), ' ', 2) AS acl
			FROM	(
				SELECT n.nspname, c.relname, a.attname, generate_series(1, array_upper(a.attacl, 1)) AS i, a.attacl
				FROM pg_class c 
				JOIN pg_namespace n ON c.relnamespace = n.oid
				JOIN pg_attribute_info a ON c.oid = a.attrelid 
				WHERE a.attacl IS NOT NULL
				) AS sub
			WHERE split_part(array_to_string(sub.attacl, ','), ',', i) LIKE 'group %'
			) AS sub2
		) AS sub3
	) AS sub4
ORDER BY 1, 2, 3;

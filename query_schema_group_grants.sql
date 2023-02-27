SELECT sub3.nspname AS schema_name, CASE WHEN substring(sub3.grogrant, pos, 1) = 'C' THEN 'CREATE' WHEN substring(sub3.grogrant, pos, 1) = 'U' THEN 'USAGE' END AS privilege_type, sub3.groname AS group_name
FROM 	(
	SELECT sub2.nspname, generate_series(1, length(sub2.grogrant)) AS pos, sub2.groname, sub2.grogrant
	FROM 	(
		SELECT sub.nspname, split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant 
		FROM 	(
			SELECT n.nspname, split_part(split_part(array_to_string(nspacl, ','), ',', i), ' ', 2) AS acl 
			FROM 	(
				SELECT nspname, generate_series(1, array_upper(nspacl, 1)) AS i, nspacl 
				FROM pg_namespace
				) AS n 
			WHERE split_part(array_to_string(nspacl, ','), ',', i) LIKE 'group %'
			) AS sub 
		) AS sub2
	) AS sub3
ORDER BY 1, 3, 2;

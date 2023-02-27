SELECT CASE WHEN substring(sub3.grogrant, pos, 1) = 'U' THEN 'CREATE MODEL' END AS privilege_type, sub3.groname AS group_name
FROM	(
	SELECT sub2.groname, generate_series(1, length(sub2.grogrant)) AS pos, sub2.grogrant
	FROM	(
		SELECT split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant 
		FROM 	(
			SELECT l.lanname, split_part(split_part(array_to_string(l.lanacl, ','), ',', i), ' ', 2) AS acl 
			FROM 	(
				SELECT lanname, generate_series(1, array_upper(lanacl, 1)) AS i, lanacl 
				FROM pg_language 
				WHERE lanname = 'mlfunc'
				) AS l 
			WHERE split_part(array_to_string(l.lanacl, ','), ',', l.i) LIKE 'group %'
			) AS sub
		) AS sub2
	) AS sub3
ORDER BY 2, 1;

SELECT sub3.datname AS database_name, CASE WHEN substring(sub3.grogrant, pos, 1) = 'C' THEN 'CREATE' WHEN substring(sub3.grogrant, pos, 1) = 'T' THEN 'TEMP' END AS privilege_type, sub3.groname AS group_name
FROM	(
	SELECT sub2.datname, generate_series(1, length(sub2.grogrant)) AS pos, sub2.groname, sub2.grogrant
	FROM	(
		SELECT sub.datname, split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant
		FROM 	(
			SELECT d.datname, split_part(split_part(array_to_string(d.datacl, ','), ',', i), ' ', 2) AS acl 
			FROM 	(
				SELECT datname, generate_series(1, array_upper(datacl, 1)) AS i, datacl 
				FROM pg_database
				) AS d 
			WHERE split_part(array_to_string(d.datacl, ','), ',', i) LIKE 'group %'
			) AS sub 
		) AS sub2
	) AS sub3
ORDER BY 1, 3, 2;

SELECT sub4.usename AS owner_name, sub4.nspname AS schema_name, 
CASE WHEN sub4.defaclobjtype = 'r' THEN
	CASE WHEN substring(sub4.grogrant, pos, 1) = 'a' THEN 'INSERT'
	WHEN substring(sub4.grogrant, pos, 1) = 'w' THEN 'UPDATE'
	WHEN substring(sub4.grogrant, pos, 1) = 'd' THEN 'DELETE'
	WHEN substring(sub4.grogrant, pos, 1) = 'D' THEN 'TRUNCATE'
	WHEN substring(sub4.grogrant, pos, 1) = 'r' THEN 'SELECT'
	WHEN substring(sub4.grogrant, pos, 1) = 'x' THEN 'REFERENCES'
	WHEN substring(sub4.grogrant, pos, 1) = 't' THEN 'TRIGGER'
	WHEN substring(sub4.grogrant, pos, 1) = 'R' THEN 'RULE' END 
WHEN sub4.defaclobjtype = 'f' OR sub4.defaclobjtype = 'p' THEN
	CASE WHEN substring(sub4.grogrant, pos, 1) = 'X' THEN 'EXECUTE' END END AS privilege_type, sub4.groname AS group_name
FROM	(
	SELECT sub3.usename, sub3.nspname, sub3.defaclobjtype, generate_series(1, length(sub3.grogrant)) AS pos, sub3.groname, sub3.grogrant
	FROM	(
		SELECT sub2.usename, sub2.nspname, sub2.defaclobjtype, split_part(split_part(sub2.acl, '=', 1), ' ', 2) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant 
		FROM 	(
			SELECT sub.defaclobjtype, sub.usename, sub.nspname, split_part(array_to_string(sub.defaclacl, ','), ',', i) AS acl 
			FROM 	(
				SELECT u.usename, n.nspname, d.defaclobjtype, generate_series(1, array_upper(d.defaclacl, 1)) AS i, d.defaclacl 
				FROM pg_default_acl d 
				JOIN pg_namespace n ON d.defaclnamespace = n.oid 
				JOIN pg_user u ON u.usesysid = d.defacluser
				) AS sub 
			WHERE split_part(array_to_string(sub.defaclacl, ','), ',', i) LIKE 'group %'
			) AS sub2
		) AS sub3
	) AS sub4
ORDER BY 1, 2, 4, 3;

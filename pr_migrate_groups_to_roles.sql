CREATE OR REPLACE PROCEDURE public.pr_migrate_groups_to_roles(dryrun boolean) AS 
$$
/*
-- Name: pr_migrate_groups_to_roles
-- Author: Jon Roberts
-- Parameter:
--   dryrun: True means the procedure will not execute any DDL and only RAISE INFO the commands that will be executed. False means that it is not a dryrun so the procedrue will execute the DDL commands.
--
-- Revisions:
--   2022-12-30: Initial development
--   2023-01-04: Added defaults and exception handling
--   2023-01-05: Added suppport for datashares and models
--   2023-02-15: Fixed defaults
--   2023-02-27: Fixed DROP default permission 
--   2023-05-09: Added column level security grants
-- Actions:
--   Create Roles
--   Assign users to Roles
--   Databases to Roles
--   Schemas to Roles
--   Tables to Roles
--   Routines (Procedures and Functions) to Roles
--   Languages to Roles
--   Default privileges to schemas and users
--   Models to Roles including CREATE
--   Datashares to Roles
--   Columns to Roles
-- Important Notes:
--   The procedure is intended to simplify the migration of Groups to Roles. It creates the Roles and executes the grants so that the new Roles match the existing grants to Groups. This procedure does NOT revoke permissions from Roles so if you call this procedure, then revoke permission to a Group, and then run this procedure again, the Role will NOT have the grant revoked.
*/
DECLARE
	v_procedure varchar(255) := 'pr_migrate_groups_to_roles';
	v_location int;
	v_now timestamp;
	v_rec record;
	v_sql varchar(max);
	v_i int;
	v_counter int;
	v_grant varchar(1);
	v_action varchar(20);
	v_grant_count int;
	v_routine_type varchar(10);
	v_previous_datashare_name varchar(128) := '';
	v_previous_identity_name varchar(128) := '';
	v_previous_group_name varchar(128) := '';
	v_previous_schema_name varchar(128) := '';
	v_previous_table_name varchar(128) := '';
	v_columns varchar(max) := '';
	v_target varchar(max) := '';
	v_grants varchar(max) := '';
BEGIN
	--Create Roles
	v_location := 1000;
	FOR v_rec IN SELECT g.groname FROM pg_group g LEFT OUTER JOIN svv_roles r ON g.groname = r.role_name WHERE r.role_id IS NULL ORDER BY 1 LOOP
		v_sql := 'CREATE ROLE "' || v_rec.groname || '"';
		RAISE INFO '%', v_sql;
		IF dryrun IS NOT TRUE THEN
			EXECUTE v_sql;
		END IF;
	END LOOP;

	--Grant Users to Roles
	v_location := 2000;
	FOR v_rec IN SELECT u.usename, g.groname FROM (SELECT groname, grolist, generate_series(1, array_upper(grolist, 1)) AS i FROM pg_group) AS g JOIN pg_user u ON g.grolist[i] = u.usesysid ORDER BY u.usename, g.groname LOOP
		v_sql := 'GRANT ROLE "' || v_rec.groname || '" TO "' || v_rec.usename || '";';
		RAISE INFO '%', v_sql;
		IF dryrun IS NOT TRUE THEN
			EXECUTE v_sql;
		END IF;
	END LOOP;

	--Databases
	v_location := 3000;
	<<databases>>
	FOR v_rec IN SELECT sub.datname, split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT d.datname, split_part(split_part(array_to_string(d.datacl, ','), ',', i), ' ', 2) AS acl FROM	(SELECT datname, generate_series(1, array_upper(datacl, 1)) AS i, datacl FROM pg_database) AS d WHERE split_part(array_to_string(d.datacl, ','), ',', i) LIKE 'group %') AS sub ORDER BY 1, 2 LOOP
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'C' THEN
				v_action := 'CREATE';
			ELSIF v_grant = 'T' THEN
				v_action := 'TEMPORARY';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'GRANT ' || v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			v_sql := v_sql || ' ON DATABASE ' || v_rec.datname || ' TO ROLE "' || v_rec.groname || '";';
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP databases;

	--Schemas to Roles
	v_location := 4000;
	<<schemas>>
	FOR v_rec IN SELECT sub.nspname, split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT n.nspname, split_part(split_part(array_to_string(nspacl, ','), ',', i), ' ', 2) AS acl FROM (SELECT nspname, generate_series(1, array_upper(nspacl, 1)) AS i, nspacl FROM pg_namespace) AS n WHERE split_part(array_to_string(nspacl, ','), ',', i) LIKE 'group %') AS sub ORDER BY 1, 2 LOOP
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'U' THEN
				v_action := 'USAGE';
			ELSIF v_grant = 'C' THEN
				v_action := 'CREATE';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'GRANT ' || v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			v_sql := v_sql || ' ON SCHEMA "' || v_rec.nspname || '" TO ROLE "' || v_rec.groname || '";';
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP schemas;

	--Tables to Roles
	v_location := 5000;
	<<tables>>
	FOR v_rec IN SELECT sub2.nspname, sub2.relname, split_part(sub2.acl, '=', 1) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT sub.nspname, sub.relname, split_part(split_part(array_to_string(sub.relacl, ','), ',', i), ' ', 2) AS acl FROM (SELECT n.nspname, c.relname, generate_series(1, array_upper(c.relacl, 1)) AS i, c.relacl FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid) AS sub WHERE split_part(array_to_string(sub.relacl, ','), ',', i) LIKE 'group %') AS sub2 ORDER BY 1, 2 LOOP 
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'a' THEN
				v_action := 'INSERT';
			ELSIF v_grant = 'w' THEN
				v_action := 'UPDATE';
			ELSIF v_grant = 'd' THEN
				v_action := 'DELETE';
			ELSIF v_grant = 'r' THEN
				v_action := 'SELECT';
			ELSIF v_grant = 'x' THEN
				v_action := 'REFERENCES';
			ELSIF v_grant = 't' THEN
				v_action := 'TRIGGER';
			ELSIF v_grant = 'R' THEN
				v_action := 'RULE';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'GRANT ' || v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			v_sql := v_sql || ' ON "' || v_rec.nspname || '"."' || v_rec.relname || '" TO ROLE "' || v_rec.groname || '";';
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP tables;

	--Routines
	v_location := 6000;
	<<routines>>
	FOR v_rec IN SELECT sub2.nspname, sub2.proname, sub2.lanname, sub2.proargs, split_part(sub2.acl, '=', 1) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT sub.nspname, sub.proname, sub.lanname, sub.proargs, split_part(split_part(array_to_string(sub.proacl, ','), ',', i), ' ', 2) AS acl FROM (SELECT n.nspname, p.proname, l.lanname, oidvectortypes(p.proargtypes) proargs, generate_series(1, array_upper(p.proacl, 1)) as i, p.proacl FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN pg_language l ON p.prolang = l.oid JOIN pg_user u ON p.proowner = u.usesysid WHERE l.lanname <> 'mlfunc' AND u.usename <> 'rdsdb' AND p.proacl IS NOT NULL) AS sub WHERE split_part(array_to_string(sub.proacl, ','), ',', i) LIKE 'group %') AS sub2 ORDER BY 1, 2 LOOP
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		IF v_rec.lanname = 'plpgsql' THEN
			v_routine_type := 'PROCEDURE';
		ELSIF v_rec.lanname = 'sql' OR v_rec.lanname = 'plpythonu' THEN
			v_routine_type := 'FUNCTION';
		END IF;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'X' THEN
				v_action := 'EXECUTE';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'GRANT ' || v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			v_sql := v_sql || ' ON ' || v_routine_type ||  ' "' || v_rec.nspname || '"."' || v_rec.proname || '"(' || v_rec.proargs || ') TO ROLE "' || v_rec.groname || '";';
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP routines;

	--Languages
	v_location := 7000;
	<<languages>>
	FOR v_rec IN SELECT sub.lanname, split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT l.lanname, split_part(split_part(array_to_string(l.lanacl, ','), ',', i), ' ', 2) AS acl FROM	(SELECT lanname, generate_series(1, array_upper(lanacl, 1)) AS i, lanacl FROM pg_language) AS l WHERE l.lanname <> 'mlfunc' AND split_part(array_to_string(l.lanacl, ','), ',', i) LIKE 'group %') AS sub ORDER BY 1, 2 LOOP
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'U' THEN
				v_action := 'USAGE';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'GRANT ' || v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			v_sql := v_sql || ' ON LANGUAGE ' || v_rec.lanname || ' TO ROLE "' || v_rec.groname || '";';
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP languages;

	--Datashares
	v_location := 8000;
	v_counter := 0;
	<<datashares>>
	FOR v_rec IN SELECT datashare_name, identity_name, privilege_type FROM svv_datashare_privileges WHERE identity_type = 'group' ORDER BY 1, 2, 3 LOOP
		IF v_previous_datashare_name = v_rec.datashare_name AND v_previous_identity_name = v_rec.identity_name THEN
			v_sql := v_sql || ', ' || v_rec.privilege_type;
		ELSE
			IF v_counter > 0 THEN
				v_sql := v_sql || ' ON DATASHARE ' || v_previous_datashare_name || ' TO ROLE "' || v_previous_identity_name || '";';
				RAISE INFO '%', v_sql;
				IF dryrun IS NOT TRUE THEN
					EXECUTE v_sql;
				END IF;
			END IF;
			v_sql := 'GRANT ' || v_rec.privilege_type;
		END IF;
		v_previous_datashare_name := v_rec.datashare_name;
		v_previous_identity_name := v_rec.identity_name;
		v_counter := v_counter + 1;
	END LOOP datashares;
	IF v_counter > 0 THEN
		v_sql := v_sql || ' ON DATASHARE ' || v_previous_datashare_name || ' TO ROLE "' || v_previous_identity_name || '";';
		RAISE INFO '%', v_sql;
		IF dryrun IS NOT TRUE THEN
			EXECUTE v_sql;
		END IF;
	END IF;

	--Models
	v_location := 9000;
	<<models>>
	FOR v_rec IN SELECT namespace_name, model_name, identity_name, privilege_type FROM svv_ml_model_privileges WHERE identity_type = 'group' ORDER BY 1, 2, 3 LOOP
		v_sql := 'GRANT ' || v_rec.privilege_type || ' ON MODEL "' || v_rec.namespace_name || '"."' || v_rec.model_name || '" TO ROLE "' || v_rec.identity_name || '"';
		RAISE INFO '%', v_sql;
		IF dryrun IS NOT TRUE THEN
			EXECUTE v_sql;
		END IF;
	END LOOP models;

	v_location := 9500;
	<<model_create>>
	FOR v_rec IN SELECT split_part(sub.acl, '=', 1) AS groname, split_part(split_part(sub.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT l.lanname, split_part(split_part(array_to_string(l.lanacl, ','), ',', i), ' ', 2) AS acl FROM (SELECT lanname, generate_series(1, array_upper(lanacl, 1)) AS i, lanacl FROM pg_language WHERE lanname = 'mlfunc') AS l WHERE split_part(array_to_string(l.lanacl, ','), ',', l.i) LIKE 'group %') AS sub ORDER BY 1, 2 LOOP
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'U' THEN
				v_action := 'CREATE MODEL';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'GRANT ' || v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			v_sql := v_sql || ' TO ROLE "' || v_rec.groname || '";';
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP model_create;
	
	--Defaults to Schemas
	v_location := 10000;
	<<defaults>>
        FOR v_rec IN 
	SELECT sub2.usename, sub2.nspname, sub2.defaclobjtype, split_part(split_part(sub2.acl, '=', 1), ' ', 2) AS groname, split_part(split_part(sub2.acl, '=', 2), '/', 1) AS grogrant FROM (SELECT sub.defaclobjtype, sub.usename, sub.nspname, split_part(array_to_string(sub.defaclacl, ','), ',', i) AS acl FROM (SELECT u.usename, n.nspname, d.defaclobjtype, generate_series(1, array_upper(d.defaclacl, 1)) AS i, d.defaclacl FROM pg_default_acl d JOIN pg_namespace n ON d.defaclnamespace = n.oid JOIN pg_user u ON u.usesysid = d.defacluser) AS sub WHERE split_part(array_to_string(sub.defaclacl, ','), ',', i) LIKE 'group %') AS sub2 ORDER BY 2, 3, 4 LOOP
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			--r=tables
			IF v_rec.defaclobjtype = 'r' THEN
				IF v_grant = 'a' THEN
					v_action := 'INSERT';
				ELSIF v_grant = 'w' THEN
					v_action := 'UPDATE';
				ELSIF v_grant = 'd' THEN
					v_action := 'DELETE';
				ELSIF v_grant = 'r' THEN
					v_action := 'SELECT';
				ELSIF v_grant = 'x' THEN
					v_action := 'REFERENCES';
				ELSIF v_grant = 'D' THEN
					v_action := 'DROP';
				ELSIF v_grant = 't' THEN
					v_action := 'TRIGGER';
				ELSIF v_grant = 'R' THEN
					v_action := 'RULE';
				END IF;
			--f=functions; p=procedures
			ELSIF v_rec.defaclobjtype = 'f' OR v_rec.defaclobjtype = 'p' THEN
				IF v_grant = 'X' THEN
					v_action := 'EXECUTE';
				END IF;
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_sql := 'ALTER DEFAULT PRIVILEGES FOR USER "' || v_rec.usename || '" IN SCHEMA "' || v_rec.nspname || '" GRANT '|| v_action;
			ELSE
				v_sql := v_sql || ', ' || v_action;
			END IF;
		END LOOP grants;
		IF v_counter > 0 THEN
			IF v_rec.defaclobjtype = 'r' THEN
				v_sql := v_sql || ' ON TABLES TO ROLE "' || v_rec.groname || '";';
			ELSIF v_rec.defaclobjtype = 'f' THEN
				v_sql := v_sql || ' ON FUNCTIONS TO ROLE "' || v_rec.groname || '";';
			ELSIF v_rec.defaclobjtype = 'p' THEN
				v_sql := v_sql || ' ON PROCEDURES TO ROLE "' || v_rec.groname || '";';
			END IF;
			RAISE INFO '%', v_sql;
			IF dryrun IS NOT TRUE THEN
				EXECUTE v_sql;
			END IF;
		END IF;
	END LOOP defaults;

	--Columns to Roles
	v_location := 11000;
	v_counter := 0;
	<<columns>>
	FOR v_rec IN
	SELECT sub3.groname, sub3.nspname, sub3.relname, sub3.attname, sub3.grogrant
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
	ORDER BY 1, 2, 3 LOOP
		IF v_previous_group_name = v_rec.groname AND v_previous_schema_name = v_rec.nspname AND v_previous_table_name = v_rec.relname THEN
			v_sql := v_sql || ', ' || v_rec.attname;
			v_columns := v_columns || ', ' || v_rec.attname;
		ELSE
			IF v_counter > 0 THEN
				v_columns := v_columns || ')';
				v_target := 'ON "' || v_rec.nspname || '"."' || v_rec.relname || '" TO ROLE "' || v_rec.groname || '";';
				v_grant_count := len(v_rec.grogrant);
				v_counter := 0;
				<<grants>>
				FOR v_i IN 1..v_grant_count LOOP
					v_grant := substring(v_rec.grogrant, v_i, 1);
					IF v_grant = 'w' THEN
						v_action := 'UPDATE';
					ELSIF v_grant = 'r' THEN
						v_action := 'SELECT';
					END IF;
					v_counter := v_counter + 1;
					IF v_counter = 1 THEN
						v_grants := 'GRANT ' || v_action || ' ' || v_columns;
					ELSE
						v_grants := v_grants || ', ' || v_action || ' ' || v_columns;
					END IF;
				END LOOP grants;

				v_sql := v_grants || ' ' || v_target;
				RAISE INFO '%', v_sql;
				IF dryrun IS NOT TRUE THEN
					EXECUTE v_sql;
				END IF;
			END IF;
			v_sql := '';
			v_columns := '(' || v_rec.attname;
			v_target := '';
		END IF;

		v_previous_group_name := v_rec.groname;
		v_previous_schema_name := v_rec.nspname;
		v_previous_table_name := v_rec.relname;
		v_counter := v_counter + 1;
	END LOOP columns;
	IF v_counter > 0 THEN
		v_target := 'ON "' || v_rec.nspname || '"."' || v_rec.relname || '" TO ROLE ' || v_rec.groname || '";';
		v_columns := v_columns || ')';
		v_grant_count := len(v_rec.grogrant);
		v_counter := 0;
		<<grants>>
		FOR v_i IN 1..v_grant_count LOOP
			v_grant := substring(v_rec.grogrant, v_i, 1);
			IF v_grant = 'w' THEN
				v_action := 'UPDATE';
			ELSIF v_grant = 'r' THEN
				v_action := 'SELECT';
			END IF;
			v_counter := v_counter + 1;
			IF v_counter = 1 THEN
				v_grants := 'GRANT ' || v_action || ' ' || v_columns;
			ELSE
				v_grants := v_grants || ', ' || v_action || ' ' || v_columns;
			END IF;
		END LOOP grants;

		v_sql := v_grants || ' ' || v_target;
		RAISE INFO '%', v_sql;
		IF dryrun IS NOT TRUE THEN
			EXECUTE v_sql;
		END IF;
	END IF;

EXCEPTION
	WHEN OTHERS THEN
		v_now := timeofday();
		RAISE EXCEPTION '(%:%:%:%)', v_location, v_now, v_procedure, sqlerrm;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;

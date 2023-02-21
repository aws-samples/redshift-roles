SELECT u.usesysid AS user_id, u.usename AS user_name, g.grosysid AS group_id, g.groname AS group_name
FROM pg_group g
JOIN pg_user u ON u.usesysid = ANY(g.grolist)
ORDER BY g.groname, u.usesysid;

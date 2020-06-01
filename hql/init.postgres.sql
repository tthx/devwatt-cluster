CREATE USER hive WITH PASSWORD 'D@$#H0le99*';
CREATE DATABASE metastore;
\c metastore;
\i /opt/hive/scripts/metastore/upgrade/postgres/hive-schema-4.0.0.postgres.sql;
\pset tuples_only on
\o /tmp/grant-privs
SELECT 'GRANT SELECT,INSERT,UPDATE,DELETE ON "'  || schemaname || '". "' ||tablename ||'" TO hive ;'
FROM pg_tables
WHERE tableowner = CURRENT_USER and schemaname = 'public';
\o
\pset tuples_only off
\i /tmp/grant-privs
\q

CREATE USER impala WITH PASSWORD 'D@$#H0le99*';
\pset tuples_only on
\o /tmp/grant-privs
SELECT 'GRANT SELECT,INSERT,UPDATE,DELETE ON "'  || schemaname || '". "' ||tablename ||'" TO impala ;'
FROM pg_tables
WHERE tableowner = CURRENT_USER and schemaname = 'public';
\o
\pset tuples_only off
\i /tmp/grant-privs

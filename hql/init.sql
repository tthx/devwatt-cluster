DROP DATABASE metastore;
DROP USER hive;
CREATE USER hive WITH PASSWORD 'azerty';
CREATE DATABASE metastore WITH OWNER hive;
\c metastore;
\i /opt/hive/scripts/metastore/upgrade/postgres/hive-schema-3.1.0.postgres.sql;
\pset tuples_only on
\o /tmp/grant-privs
SELECT 'GRANT SELECT,INSERT,UPDATE,DELETE ON "'  || schemaname || '". "' ||tablename ||'" TO hive ;'
FROM pg_tables
WHERE tableowner = CURRENT_USER and schemaname = 'public';
\o
\pset tuples_only off
\i /tmp/grant-privs
\q

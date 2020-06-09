DROP DATABASE metastore;
DROP USER hive;
DROP USER impala;
CREATE USER hive WITH PASSWORD 'azerty';
CREATE USER impala WITH PASSWORD 'azerty';
CREATE DATABASE hive_metastore WITH OWNER hive;
CREATE DATABASE impala_metastore WITH OWNER impala;
\c hive_metastore;
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

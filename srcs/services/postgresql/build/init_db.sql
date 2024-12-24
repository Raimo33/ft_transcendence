CREATE DATABASE pongfumasters WITH OWNER = postgresql;

--#TODO pg_cachetools

\c pongfumasters

\cd /tmp/init_db

\i init_tables.sql
\i init_views.sql
\i init_partitions.sql
\i init_triggers.sql
\i init_rbac.sql
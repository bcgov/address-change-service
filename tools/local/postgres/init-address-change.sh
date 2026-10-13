#!/bin/sh
set -eu

psql \
  --set=ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${POSTGRES_DB}" \
  --set=migration_username="${ADDRESS_CHANGE_MIGRATION_USERNAME}" \
  --set=migration_password="${ADDRESS_CHANGE_MIGRATION_PASSWORD}" \
  --set=runtime_username="${ADDRESS_CHANGE_RUNTIME_USERNAME}" \
  --set=runtime_password="${ADDRESS_CHANGE_RUNTIME_PASSWORD}" \
  --set=database_name="${POSTGRES_DB}" \
  --set=schema_name="${ADDRESS_CHANGE_SCHEMA}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'migration_username', :'migration_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'migration_username')
\gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'runtime_username', :'runtime_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'runtime_username')
\gexec

SELECT format('CREATE SCHEMA %I AUTHORIZATION %I', :'schema_name', :'migration_username')
WHERE NOT EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = :'schema_name')
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'migration_username')
\gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'runtime_username')
\gexec
SELECT format('GRANT USAGE, CREATE ON SCHEMA %I TO %I', :'schema_name', :'migration_username')
\gexec
SELECT format('GRANT USAGE ON SCHEMA %I TO %I', :'schema_name', :'runtime_username')
\gexec

SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
  :'migration_username', :'schema_name', :'runtime_username'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT USAGE, SELECT ON SEQUENCES TO %I',
  :'migration_username', :'schema_name', :'runtime_username'
)
\gexec
SELECT format('ALTER ROLE %I SET search_path TO %I, public', :'migration_username', :'schema_name')
\gexec
SELECT format('ALTER ROLE %I SET search_path TO %I, public', :'runtime_username', :'schema_name')
\gexec
SQL

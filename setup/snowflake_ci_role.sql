-- One-time setup of the least-privilege Snowflake identity used by GitHub Actions CI.
-- Idempotent: safe to re-run. Contains no account identifier.
--
-- 1. Generate the key pair locally (PKCS8, unencrypted so it fits in a GitHub secret).
--    Never commit these files.
--      openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -nocrypt -out dbt_ci_key.p8
--      openssl rsa -in dbt_ci_key.p8 -pubout -out dbt_ci_key.pub
--
-- 2. Replace <paste_public_key> below with the content of dbt_ci_key.pub,
--    WITHOUT the BEGIN/END PUBLIC KEY lines (the base64 body only).
--
-- 3. Run the blocks in order with the roles named in each section
--    (tested on a fresh trial account):
--      SYSADMIN      : warehouse and database creation, grants on them
--      SECURITYADMIN : role and user creation, role grants
--      ACCOUNTADMIN  : IMPORTED PRIVILEGES on the shared sample database
--
-- 4. Store the full content of dbt_ci_key.p8 (BEGIN/END lines included) in the GitHub
--    secret DBT_SNOWFLAKE_PRIVATE_KEY, then delete the local key files.

-- SYSADMIN: compute and target database
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS DBT_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
CREATE DATABASE IF NOT EXISTS ANALYTICS;

-- SECURITYADMIN: role and user
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DBT_CI_ROLE;
GRANT ROLE DBT_CI_ROLE TO ROLE SYSADMIN;

CREATE USER IF NOT EXISTS DBT_CI_USER
  TYPE = SERVICE
  DEFAULT_ROLE = DBT_CI_ROLE
  DEFAULT_WAREHOUSE = DBT_WH;
ALTER USER DBT_CI_USER SET RSA_PUBLIC_KEY = '<paste_public_key>';
GRANT ROLE DBT_CI_ROLE TO USER DBT_CI_USER;

-- SYSADMIN: warehouse and target database
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE DBT_WH TO ROLE DBT_CI_ROLE;
GRANT USAGE ON DATABASE ANALYTICS TO ROLE DBT_CI_ROLE;
GRANT CREATE SCHEMA ON DATABASE ANALYTICS TO ROLE DBT_CI_ROLE;

-- ACCOUNTADMIN: read access to the sample data share
USE ROLE ACCOUNTADMIN;

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_CI_ROLE;

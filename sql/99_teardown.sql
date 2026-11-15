-- =====================================================================
-- 99_teardown.sql
-- Removes all objects created by this implementation. Destructive.
-- =====================================================================

USE ROLE ACCOUNTADMIN;

DROP SNOWFLAKE.CORE.QUOTA IF EXISTS PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA;
DROP SNOWFLAKE.CORE.QUOTA IF EXISTS PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA;

DROP DATABASE IF EXISTS PUQ_GOVERNANCE_DB;

DROP ROLE IF EXISTS QUOTA_ADMIN;
DROP ROLE IF EXISTS ANALYST;
DROP ROLE IF EXISTS DATA_ENG;

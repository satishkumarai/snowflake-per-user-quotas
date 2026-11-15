-- =====================================================================
-- 01_create_quotas.sql
-- Creates two per-user quota instances:
--   * PUQ_AI_STANDARD_QUOTA  - AI-credit domains, standard tier
--   * PUQ_WH_STANDARD_QUOTA  - compute (warehouse) domains, standard tier
-- AI-credit and compute domains cannot share one quota, so each usage
-- unit gets its own quota. Run 00_setup_database_and_roles.sql first.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

CREATE SNOWFLAKE.CORE.QUOTA IF NOT EXISTS PUQ_AI_STANDARD_QUOTA();
CREATE SNOWFLAKE.CORE.QUOTA IF NOT EXISTS PUQ_WH_STANDARD_QUOTA();

-- Default per-user limits (whole credits, independent cycles).
-- Adjust values to your environment before applying.
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(500, 'MONTHLY');
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(150, 'WEEKLY');

CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!SET_PER_USER_LIMIT(1000, 'MONTHLY');

-- Shared resources: without at least one, a quota measures 0 credits.
-- AI quota tracks AI domains; warehouse quota tracks compute domains.
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX_CODE');

CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!ADD_SHARED_RESOURCE('WAREHOUSE');

-- Delegate administration to the QUOTA_ADMIN role.
GRANT SNOWFLAKE.CORE.QUOTA ROLE PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADMIN
    TO ROLE QUOTA_ADMIN;
GRANT SNOWFLAKE.CORE.QUOTA ROLE PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!ADMIN
    TO ROLE QUOTA_ADMIN;

-- =====================================================================
-- 04_verify_and_monitor.sql
-- Verification and day-2 monitoring queries for the quota setup.
-- =====================================================================

USE ROLE QUOTA_ADMIN;

-- List quota instances in the governance schema
SHOW SNOWFLAKE.CORE.QUOTA INSTANCES IN SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- Full user scope, including role-based configuration and shared resources.
-- Returns a JSON string; parse it to inspect as VARIANT.
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!GET_QUOTA_SCOPE_V2();

-- Parse the scope for the last call
SELECT PARSE_JSON("GET_QUOTA_SCOPE_V2"):users AS users,
       PARSE_JSON("GET_QUOTA_SCOPE_V2"):shared_resources AS shared_resources
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Configuration: limits, enforcement, admin emails
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!GET_CONFIG();

-- Resolved user population.
-- NOTE: role grants/revokes and tag changes take ~10-15 minutes to
-- appear here. Do not assume immediate effect after an IAM change.
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!GET_USERS();

-- Configured per-user limit overrides
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!LIST_USER_QUOTA_OVERRIDES();

-- Legacy scope view (no roles) - still works, but prefer GET_QUOTA_SCOPE_V2
-- CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!GET_QUOTA_SCOPE();

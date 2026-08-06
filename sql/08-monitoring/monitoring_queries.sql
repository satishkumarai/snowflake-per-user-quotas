-- PUQ 08: Monitoring Queries
-- =============================================================================
-- Data sources:
--   Quota methods: GET_SPENDING_DETAILS_BY_USERS, GET_PER_USER_USAGE_PREVIEW
--   Event table: snowflake.telemetry.events
--   Account usage: snowflake.account_usage.quota_access_block_history
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE and ACCOUNTADMIN
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- Near-real-time AI usage (~2h delay).
CALL PUQ_AI_STANDARD_QUOTA!GET_PER_USER_USAGE_PREVIEW(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- Finalized spending (current month).
CALL PUQ_AI_STANDARD_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- Warehouse spending.
CALL PUQ_WH_STANDARD_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- Enforcement status.
CALL PUQ_AI_STANDARD_QUOTA!GET_ACTIVE_BLOCKS();
CALL PUQ_AI_STANDARD_QUOTA!GET_ENFORCEMENT_HISTORY(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- Event table (last 7 days).
USE ROLE ACCOUNTADMIN;
SELECT
    TIMESTAMP,
    RECORD:name::STRING            AS EVENT_NAME,
    RECORD:severity_text::STRING   AS SEVERITY,
    VALUE:message::STRING          AS MESSAGE
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC
LIMIT 50;

-- Block history.
SELECT *
FROM snowflake.account_usage.quota_access_block_history
WHERE CREATED_ON > DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY CREATED_ON DESC
LIMIT 50;

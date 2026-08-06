-- PUQ Monitoring: Spending, Enforcement, and Event Table Queries
-- =============================================================================
-- Data sources for quota monitoring:
--   1. Quota methods: GET_SPENDING_DETAILS_BY_USERS (finalized)
--   2. Quota methods: GET_PER_USER_USAGE_PREVIEW (near-real-time, ~2h delay)
--   3. Quota methods: GET_ACTIVE_BLOCKS, GET_ENFORCEMENT_HISTORY
--   4. Event table: snowflake.telemetry.events (SCOPE['name'] = 'snow.cost.quota')
--   5. Account usage: snowflake.account_usage.quota_access_block_history
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE and ACCOUNTADMIN
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════════
-- SPENDING DATA
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- Near-real-time usage (~2h delay, similar to TAG_REFERENCES latency).
-- Use when you need current-month data without waiting for full pipeline.
CALL PUQ_AI_STANDARD_QUOTA!GET_PER_USER_USAGE_PREVIEW(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- Finalized spending (current or prior month only — older dates return nothing).
-- Returns: USER_ID, USER_NAME, SERVICE_TYPE, ENTITY_TYPE, ENTITY_NAME,
--          CREDITS_SPEND, USAGE_TIMESTAMP
CALL PUQ_AI_STANDARD_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- Warehouse quota spending.
CALL PUQ_WH_STANDARD_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- ENFORCEMENT STATUS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Currently blocked users.
CALL PUQ_AI_STANDARD_QUOTA!GET_ACTIVE_BLOCKS();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_ACTIVE_BLOCKS();

-- Block/unblock history (both start and end dates required).
CALL PUQ_AI_STANDARD_QUOTA!GET_ENFORCEMENT_HISTORY(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENT TABLE (Notifications, Custom Actions, Errors)
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;

-- All quota events (last 7 days).
SELECT
    TIMESTAMP,
    RECORD:name::STRING            AS EVENT_NAME,
    RECORD:severity_text::STRING   AS SEVERITY,
    VALUE:message::STRING          AS MESSAGE,
    RESOURCE_ATTRIBUTES
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC
LIMIT 100;

-- Errors only (failed actions, unverified emails).
SELECT
    TIMESTAMP,
    RECORD:name::STRING  AS EVENT_NAME,
    VALUE:message::STRING AS ERROR_MESSAGE
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND RECORD:severity_text::STRING = 'ERROR'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- CROSS-QUOTA BLOCK HISTORY (Account Usage View)
-- Shows which user was blocked by which quota over time.
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT *
FROM snowflake.account_usage.quota_access_block_history
WHERE CREATED_ON > DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY CREATED_ON DESC
LIMIT 50;

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION AUDIT (all quotas)
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

CALL PUQ_AI_STANDARD_QUOTA!GET_CONFIG();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_CONFIG();
CALL PUQ_WH_STANDARD_QUOTA!GET_CONFIG();

CALL PUQ_AI_STANDARD_QUOTA!GET_QUOTA_SCOPE();
CALL PUQ_AI_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();
CALL PUQ_WH_STANDARD_QUOTA!GET_CUSTOM_ACTIONS();

-- PUQ 09: Reporting Queries for FinOps Dashboards
-- =============================================================================
-- Queries for Snowsight, Streamlit, Tableau, or Power BI dashboards.
-- ROLE REQUIRED: ACCOUNTADMIN
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Report 1: Quota event breakdown (notifications, actions, errors).
SELECT
    DATE_TRUNC('DAY', TIMESTAMP) AS EVENT_DAY,
    RECORD:name::STRING AS EVENT_TYPE,
    RECORD:severity_text::STRING AS SEVERITY,
    COUNT(*) AS EVENT_COUNT
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY EVENT_DAY, EVENT_TYPE, SEVERITY
ORDER BY EVENT_DAY DESC;

-- Report 2: Block enforcement activity.
SELECT
    DATE_TRUNC('DAY', CREATED_ON) AS BLOCK_DAY,
    COUNT(*) AS BLOCK_EVENTS
FROM snowflake.account_usage.quota_access_block_history
WHERE CREATED_ON > DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY BLOCK_DAY
ORDER BY BLOCK_DAY DESC;

-- Report 3: User tag distribution (for capacity planning).
SELECT
    TAG_NAME,
    TAG_VALUE,
    COUNT(*) AS USER_COUNT
FROM snowflake.account_usage.tag_references
WHERE OBJECT_TYPE = 'USER'
  AND TAG_DATABASE = 'PUQ_GOVERNANCE_DB'
  AND TAG_SCHEMA = 'TAGS'
  AND DELETED IS NULL
GROUP BY TAG_NAME, TAG_VALUE
ORDER BY TAG_NAME, USER_COUNT DESC;

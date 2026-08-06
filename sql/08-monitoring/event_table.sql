-- PUQ 08c: Event Table Monitoring
-- =============================================================================
-- Per docs: "Quota-related operational events are recorded in the Snowflake
-- Event Table, providing visibility into whether notifications and custom
-- actions were successfully executed."
--
-- Event types:
--   INFO: Successful notification delivery, custom action execution,
--         cycle-start action execution.
--   ERROR: Custom action failures, cycle-start action failures,
--          invalid notification integrations, unverified email recipients.
--
-- Default event table: snowflake.telemetry.events
-- Scope filter: SCOPE['name'] = 'snow.cost.quota'
--
-- ROLE REQUIRED: ACCOUNTADMIN (or quota's admin role)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ═══════════════════════════════════════════════════════════════════════════════
-- ALL QUOTA EVENTS (last 24 hours)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT
    TIMESTAMP,
    RECORD:name::STRING            AS EVENT_NAME,
    RECORD:severity_text::STRING   AS SEVERITY,
    VALUE:message::STRING          AS MESSAGE,
    RESOURCE_ATTRIBUTES
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- ERRORS ONLY (failed custom actions, unverified emails, etc.)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT
    TIMESTAMP,
    RECORD:name::STRING            AS EVENT_NAME,
    VALUE:message::STRING          AS ERROR_MESSAGE,
    RESOURCE_ATTRIBUTES
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND RECORD:severity_text::STRING = 'ERROR'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUCCESSFUL NOTIFICATIONS (last 7 days)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT
    TIMESTAMP,
    VALUE:message::STRING AS NOTIFICATION_MESSAGE,
    RESOURCE_ATTRIBUTES
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND RECORD:severity_text::STRING = 'INFO'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC;

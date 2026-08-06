-- PUQ Operations: Escalation, Rollback, and Teardown
-- =============================================================================
-- Day-to-day operational procedures for managing PUQ quotas.
-- Covers: escalation, limit changes, disabling enforcement, rollback, teardown.
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE and ACCOUNTADMIN
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════════
-- ESCALATION: Move user from standard to high tier
-- Pipeline clears standard-tier blocks within ~15 minutes.
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE ACCOUNTADMIN;
-- ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'high';
-- User is now governed by PUQ_AI_HIGH_TIER_QUOTA (500 credits/month).

-- To de-escalate back:
-- ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'standard';

-- ═══════════════════════════════════════════════════════════════════════════════
-- RAISE LIMIT FOR ALL (alternative to escalation)
-- Blocks clear for users now under the new limit (~15 min propagation).
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(200);

-- ═══════════════════════════════════════════════════════════════════════════════
-- EMERGENCY: DISABLE ALL ENFORCEMENT
-- Users auto-unblocked within ~15 minutes.
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);
-- CALL PUQ_AI_HIGH_TIER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);

-- ═══════════════════════════════════════════════════════════════════════════════
-- RE-ENABLE DISABLED USER (if custom action disabled them)
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE ACCOUNTADMIN;
-- ALTER USER PUQ_DEMO_USER SET DISABLED = FALSE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- REMOVE NOTIFICATIONS (keep quotas active but stop emails)
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_AI_STANDARD_QUOTA!REMOVE_NOTIFICATION_THRESHOLD(50, 'PROJECTED');
-- CALL PUQ_AI_STANDARD_QUOTA!REMOVE_NOTIFICATION_THRESHOLD(80, 'PROJECTED');
-- CALL PUQ_AI_STANDARD_QUOTA!REMOVE_NOTIFICATION_THRESHOLD(90, 'ACTUAL');
-- CALL PUQ_AI_STANDARD_QUOTA!REMOVE_NOTIFICATION_THRESHOLD(100, 'ACTUAL');

-- ═══════════════════════════════════════════════════════════════════════════════
-- REMOVE CUSTOM ACTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_WH_STANDARD_QUOTA!REMOVE_CUSTOM_ACTIONS();
-- CALL PUQ_WH_STANDARD_QUOTA!REMOVE_CYCLE_START_ACTION();

-- ═══════════════════════════════════════════════════════════════════════════════
-- FULL TEARDOWN (removes ALL PUQ objects)
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);
-- CALL PUQ_AI_HIGH_TIER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);
-- CALL PUQ_WH_STANDARD_QUOTA!REMOVE_CUSTOM_ACTIONS();
-- CALL PUQ_WH_STANDARD_QUOTA!REMOVE_CYCLE_START_ACTION();
--
-- USE ROLE ACCOUNTADMIN;
-- DROP SNOWFLAKE.CORE.QUOTA IF EXISTS PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA;
-- DROP SNOWFLAKE.CORE.QUOTA IF EXISTS PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_HIGH_TIER_QUOTA;
-- DROP SNOWFLAKE.CORE.QUOTA IF EXISTS PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA;
-- ALTER USER PUQ_DEMO_USER UNSET TAG
--     PUQ_GOVERNANCE_DB.TAGS.COST_CENTER,
--     PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER,
--     PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT;
-- DROP USER IF EXISTS PUQ_DEMO_USER;
-- DROP ROLE IF EXISTS PUQ_QUOTA_ADMIN_ROLE;
-- DROP ROLE IF EXISTS PUQ_TEST_USER_ROLE;
-- DROP WAREHOUSE IF EXISTS PUQ_TEST_WH;
-- DROP DATABASE IF EXISTS PUQ_GOVERNANCE_DB;
-- SELECT 'PUQ TEARDOWN COMPLETE' AS STATUS;

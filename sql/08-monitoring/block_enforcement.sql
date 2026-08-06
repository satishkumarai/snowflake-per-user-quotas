-- PUQ 08b: Block Enforcement — Enable, Disable, Monitor
-- =============================================================================
-- Demonstrates all documented block enforcement methods:
--   SET_BLOCK_ENFORCEMENT_ENABLED(TRUE/FALSE) — toggle enforcement
--   GET_ACTIVE_BLOCKS()                       — who is currently blocked
--   GET_ENFORCEMENT_HISTORY('<start>', '<end>') — block/unblock history
--
-- Per docs:
--   - Block enforcement supports ONLY AI domains (not warehouses)
--   - Evaluates within minutes of a spend event (separate from eval task)
--   - Runs on Snowflake infrastructure (no customer credit cost)
--   - Blocks released automatically at cycle boundary or when limit is raised
--   - When disabled, users auto-unblocked within ~15 minutes
--   - Multiple quotas can independently block the same user
--   - View: snowflake.account_usage.quota_access_block_history
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHECK ENFORCEMENT STATE
-- ═══════════════════════════════════════════════════════════════════════════════

-- Which users are currently blocked by AI standard quota?
CALL PUQ_AI_STANDARD_QUOTA!GET_ACTIVE_BLOCKS();

-- Which users are currently blocked by AI high-tier quota?
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_ACTIVE_BLOCKS();

-- Enforcement history for the current month (both start and end dates required).
CALL PUQ_AI_STANDARD_QUOTA!GET_ENFORCEMENT_HISTORY(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISABLE ENFORCEMENT (emergency)
-- Users auto-unblocked within ~15 minutes.
-- ═══════════════════════════════════════════════════════════════════════════════

-- CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);

-- ═══════════════════════════════════════════════════════════════════════════════
-- RE-ENABLE ENFORCEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

-- CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- ═══════════════════════════════════════════════════════════════════════════════
-- CROSS-QUOTA BLOCK HISTORY (Account Usage View)
-- Shows which user was blocked by which quota over time.
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;
SELECT *
FROM snowflake.account_usage.quota_access_block_history
WHERE CREATED_ON > DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY CREATED_ON DESC
LIMIT 50;

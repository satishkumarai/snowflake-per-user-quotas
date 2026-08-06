-- PUQ 05d: Spending Limits — SET, UNSET, and GET_CONFIG
-- =============================================================================
-- Demonstrates all documented spending limit methods:
--   SET_PER_USER_LIMIT(<credits>)             — set monthly limit
--   SET_PER_USER_LIMIT(<credits>, 'DAILY')    — set daily limit
--   UNSET_PER_USER_LIMIT('DAILY')             — remove daily limit
--   GET_CONFIG()                               — view current configuration
--
-- Per docs:
--   - No enforcement occurs until a per-user spending limit is set
--   - All users in scope share the same per-user limit
--   - Daily and monthly limits are evaluated independently
--   - Limit changes take ~15 minutes to propagate
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ═══════════════════════════════════════════════════════════════════════════════
-- VIEW CURRENT CONFIGURATION
-- Returns: PER_USER_LIMIT, PER_USER_LIMIT_DAILY, BLOCK_ENFORCEMENT_ENABLED,
--          REFRESH_TIER
-- ═══════════════════════════════════════════════════════════════════════════════

CALL PUQ_AI_STANDARD_QUOTA!GET_CONFIG();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_CONFIG();
CALL PUQ_WH_STANDARD_QUOTA!GET_CONFIG();

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODIFY LIMITS (examples — uncomment to execute)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Raise the monthly limit (blocks clear for users now under new limit, ~15 min).
-- CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(200);

-- Raise the daily limit.
-- CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(20, 'DAILY');

-- Remove the daily limit entirely (monthly still enforced).
-- CALL PUQ_AI_STANDARD_QUOTA!UNSET_PER_USER_LIMIT('DAILY');

-- Verify changes took effect.
-- CALL PUQ_AI_STANDARD_QUOTA!GET_CONFIG();

-- PUQ Quota Creation: AI Standard, AI High Tier, and Warehouse Quotas
-- =============================================================================
-- Creates all 3 PUQ quotas with full domain configuration.
-- A single quota monitors EITHER warehouse OR AI domains (not both).
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ═══════════════════════════════════════════════════════════════════════════════
-- QUOTA 1: PUQ_AI_STANDARD_QUOTA
-- Domains: AI FUNCTION, CORTEX AGENT, SNOWFLAKE INTELLIGENCE, CORTEX CODE
-- Limits: 100 AI credits/month, 10/day
-- Enforcement: Block (built-in, within minutes)
-- Scope: cost_center=engineering AND usage_tier=standard (INTERSECTION)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE SNOWFLAKE.CORE.QUOTA PUQ_AI_STANDARD_QUOTA();

-- Add all AI domains.
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');

-- User scope: must match BOTH tags.
CALL PUQ_AI_STANDARD_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'standard']
    ],
    'INTERSECTION'
);

-- Set monthly and daily limits.
CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(100);
CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(10, 'DAILY');

-- Enable block enforcement (AI domains only, evaluates within minutes).
CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Opt into low-latency refresh for notifications/custom actions (<1 hour).
-- SET_REFRESH_TIER deprecated: low-latency is now default at no extra cost.
-- CALL PUQ_AI_STANDARD_QUOTA!SET_REFRESH_TIER('TIER_1H');

-- ═══════════════════════════════════════════════════════════════════════════════
-- QUOTA 2: PUQ_AI_HIGH_TIER_QUOTA (Escalation Target)
-- Limits: 500 AI credits/month, 50/day
-- Scope: cost_center=engineering AND usage_tier=high
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE SNOWFLAKE.CORE.QUOTA PUQ_AI_HIGH_TIER_QUOTA();

CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');

CALL PUQ_AI_HIGH_TIER_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'high']
    ],
    'INTERSECTION'
);

CALL PUQ_AI_HIGH_TIER_QUOTA!SET_PER_USER_LIMIT(500);
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_PER_USER_LIMIT(50, 'DAILY');
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);
-- CALL PUQ_AI_HIGH_TIER_QUOTA!SET_REFRESH_TIER('TIER_1H');  -- Deprecated

-- ═══════════════════════════════════════════════════════════════════════════════
-- QUOTA 3: PUQ_WH_STANDARD_QUOTA
-- Domains: WAREHOUSE (PUQ_TEST_WH only)
-- Limits: 50 credits/month, 5/day
-- Enforcement: Custom action only (block does NOT apply to warehouses)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE SNOWFLAKE.CORE.QUOTA PUQ_WH_STANDARD_QUOTA();

CALL PUQ_WH_STANDARD_QUOTA!ADD_SHARED_RESOURCE(
    'WAREHOUSE',
    (SELECT SYSTEM$REFERENCE('WAREHOUSE', 'PUQ_TEST_WH'))
);

CALL PUQ_WH_STANDARD_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'standard']
    ],
    'INTERSECTION'
);

CALL PUQ_WH_STANDARD_QUOTA!SET_PER_USER_LIMIT(50);
CALL PUQ_WH_STANDARD_QUOTA!SET_PER_USER_LIMIT(5, 'DAILY');

-- Verify all quotas.
CALL PUQ_AI_STANDARD_QUOTA!GET_CONFIG();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_CONFIG();
CALL PUQ_WH_STANDARD_QUOTA!GET_CONFIG();

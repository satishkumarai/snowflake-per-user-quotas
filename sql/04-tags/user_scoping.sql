-- PUQ 02b: User Scoping — UNION, INTERSECTION, and EXCLUDE_USERS patterns
-- =============================================================================
-- Demonstrates all documented user scoping methods:
--   SET_USER_TAGS — scope to users matching specific tags
--   EXCLUDE_USERS — keep all users but exclude a subset
--   GET_QUOTA_SCOPE — verify current scope configuration
--   GET_USERS — list users currently resolved into scope
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PATTERN 1: INTERSECTION (User must match ALL specified tags)
-- Use case: Non-overlapping groups for tiered escalation.
-- ═══════════════════════════════════════════════════════════════════════════════

-- PUQ_AI_STANDARD_QUOTA targets: engineering + standard tier
CALL PUQ_AI_STANDARD_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'standard']
    ],
    'INTERSECTION'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PATTERN 2: UNION (User must match ANY of the specified tags)
-- Use case: Broad governance across multiple departments.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Example (commented out — would conflict with current INTERSECTION scope):
-- CALL PUQ_AI_STANDARD_QUOTA!SET_USER_TAGS(
--     [
--         [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
--         [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'analytics']
--     ],
--     'UNION'
-- );

-- ═══════════════════════════════════════════════════════════════════════════════
-- PATTERN 3: EXCLUDE_USERS (All users EXCEPT those matching specific tags)
-- Use case: Default governance with exemptions for power users.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Example: Monitor all users except those tagged as 'unlimited' tier.
-- CALL PUQ_AI_STANDARD_QUOTA!EXCLUDE_USERS('TAG', [
--     [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'unlimited']
-- ]);

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════════

-- View the configured scope (JSON showing tags + operator).
CALL PUQ_AI_STANDARD_QUOTA!GET_QUOTA_SCOPE();

-- List users currently resolved into scope.
-- Note: TAG_REFERENCES can lag ~2 hours. Recent tag changes may not appear immediately.
CALL PUQ_AI_STANDARD_QUOTA!GET_USERS();

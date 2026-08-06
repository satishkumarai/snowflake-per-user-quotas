-- PUQ 06: Notification Thresholds and Admin Summaries
-- =============================================================================
-- Threshold types:
--   PROJECTED: Extrapolated spend (early warning). Max once/24h per user.
--   ACTUAL: Accumulated spend (hard limit). Max once/cycle per user.
-- Third argument: TRUE = notify the user directly via email.
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ── AI Standard Quota: 4-tier progressive ────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(50, 'PROJECTED', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(90, 'ACTUAL', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!SET_ADMIN_EMAILS('puq-admin@example.com');

-- ── AI High Tier Quota: lighter (trusted users) ─────────────────────────────
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE);
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_ADMIN_EMAILS('puq-admin@example.com');

-- ── Warehouse Standard Quota: progressive ────────────────────────────────────
CALL PUQ_WH_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(60, 'PROJECTED', TRUE);
CALL PUQ_WH_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
CALL PUQ_WH_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE);
CALL PUQ_WH_STANDARD_QUOTA!SET_ADMIN_EMAILS('puq-admin@example.com');

-- Verify.
CALL PUQ_AI_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();
CALL PUQ_WH_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();

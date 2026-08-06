-- PUQ 05c: Escalation — Moving users between quota tiers
-- =============================================================================
-- Demonstrates the documented escalation pattern:
--   1. User is blocked by PUQ_AI_STANDARD_QUOTA (100 credits/mo)
--   2. Admin changes their USAGE_TIER tag to 'high'
--   3. Pipeline clears standard-tier blocks (~15 min)
--   4. User is now governed by PUQ_AI_HIGH_TIER_QUOTA (500 credits/mo)
--
-- Per docs: "Changing the user's usage_tier tag moves them out of the first
-- quota's scope and into the higher-limit quota's scope. The pipeline clears
-- the user's blocks from the first quota and evaluates them against the new
-- limit, with no double-blocking and no manual unblock."
--
-- ROLE REQUIRED: ACCOUNTADMIN (for ALTER USER ... SET TAG)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ═══════════════════════════════════════════════════════════════════════════════
-- ESCALATE: Move PUQ_DEMO_USER from standard (100 credits) to high (500 credits)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Check current blocks before escalation.
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
CALL PUQ_AI_STANDARD_QUOTA!GET_ACTIVE_BLOCKS();

-- Escalate the user.
USE ROLE ACCOUNTADMIN;
ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'high';

-- After ~15 minutes:
-- - Standard-tier blocks are automatically cleared
-- - User is evaluated against PUQ_AI_HIGH_TIER_QUOTA (500 credits/mo)
-- - No double-blocking occurs

-- Verify new scope resolution (may take ~2 hours for TAG_REFERENCES).
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_USERS();

-- ═══════════════════════════════════════════════════════════════════════════════
-- DE-ESCALATE: Move back to standard tier
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;
ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'standard';

-- ═══════════════════════════════════════════════════════════════════════════════
-- ALTERNATIVE: Raise the limit for everyone (no tag change needed)
-- ═══════════════════════════════════════════════════════════════════════════════

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(200);
-- After ~15 min, blocks clear for users now under the new limit.

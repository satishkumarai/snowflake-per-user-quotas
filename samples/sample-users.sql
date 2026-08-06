-- PUQ Sample: Escalation pattern (move PUQ_DEMO_USER between tiers)

-- ═══════════════════════════════════════════════════════════════════
-- ESCALATION: Move user from standard tier (100 credits) to high tier (500 credits)
-- ═══════════════════════════════════════════════════════════════════
-- When PUQ_DEMO_USER is blocked by PUQ_AI_STANDARD_QUOTA:

-- USE ROLE ACCOUNTADMIN;
-- ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'high';
-- → Standard-tier blocks clear within ~15 minutes
-- → User now governed by PUQ_AI_HIGH_TIER_QUOTA (500 credits/month)

-- ═══════════════════════════════════════════════════════════════════
-- DE-ESCALATION: Move back to standard tier
-- ═══════════════════════════════════════════════════════════════════
-- ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'standard';

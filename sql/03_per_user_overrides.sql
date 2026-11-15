-- =====================================================================
-- 03_per_user_overrides.sql
-- Per-user, per-cycle credit limit overrides (GA Nov 11, 2026).
--
-- An override gives a specific user a higher or lower limit than the
-- quota default - without changing the user scope and without creating
-- another quota. An optional expiration date reverts the exception
-- automatically.
-- =====================================================================

USE ROLE QUOTA_ADMIN;

-- Give ALICE a temporary 2,500-credit monthly limit on the AI quota.
-- Reverts to the quota default on 2026-12-01.
-- Signature: SET_USER_QUOTA_OVERRIDE(<usernames>, '<cycle>', <limit>[, '<expires_on>'])
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!SET_USER_QUOTA_OVERRIDE(
    ['ALICE'], 'MONTHLY', 2500, '2026-12-01'
);

-- Give a contractor a lower weekly limit with no expiration.
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!SET_USER_QUOTA_OVERRIDE(
    ['CONTRACTOR_BOB'], 'WEEKLY', 100
);

-- Inspect configured overrides.
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!LIST_USER_QUOTA_OVERRIDES();

-- Remove overrides (pick the one that matches the intent).
-- CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!REMOVE_USER_QUOTA_OVERRIDE('ALICE', 'MONTHLY');
-- CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!REMOVE_USER_QUOTA_OVERRIDES_BY_USER('ALICE');
-- CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!REMOVE_USER_QUOTA_OVERRIDES_BY_CYCLE('MONTHLY');
-- CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!REMOVE_ALL_USER_QUOTA_OVERRIDES();

-- Governance note: an override is a controlled exception, not a routine
-- assignment mechanism. Record requester, justification, cycle,
-- expiration, and approver outside Snowflake (or in a tracking table)
-- for every override you grant.

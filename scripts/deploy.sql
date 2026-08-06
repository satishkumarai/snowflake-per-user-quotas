-- Snowflake Per-User Quotas: Production-Grade End-to-End Implementation
-- =============================================================================
--
--  PER-USER QUOTAS (PUBLIC PREVIEW) — COMPLETE REFERENCE IMPLEMENTATION
--
-- =============================================================================
--
--  DESCRIPTION:
--    Enterprise-grade deployment of Snowflake Per-User Quotas covering:
--    • AI credit governance (block enforcement)
--    • Warehouse compute governance (custom action enforcement)
--    • Multi-tier escalation (standard → high tier)
--    • Tag-based user scoping (INTERSECTION + EXCLUDE_USERS)
--    • Notification thresholds (PROJECTED + ACTUAL)
--    • Admin summary notifications
--    • Custom actions (disable users at 100%)
--    • Cycle-start reset action (re-enable users monthly)
--    • Low-latency evaluation (TIER_1H)
--    • Monitoring, reporting, and event table queries
--    • Full validation suite
--    • Complete cleanup / teardown
--
--  NAMING CONVENTION:
--    Database:    PUQ_GOVERNANCE_DB        (Per-User Quota Governance)
--    Schemas:     PUQ_GOVERNANCE_DB.QUOTAS
--                 PUQ_GOVERNANCE_DB.TAGS
--                 PUQ_GOVERNANCE_DB.ACTIONS
--    Warehouse:   PUQ_TEST_WH
--    Roles:       PUQ_QUOTA_ADMIN_ROLE     (creates/manages quotas)
--                 PUQ_TEST_USER_ROLE       (operational role for test user)
--    User:        PUQ_DEMO_USER            (dedicated test user)
--    Tags:        PUQ_GOVERNANCE_DB.TAGS.COST_CENTER
--                 PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER
--                 PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT
--    Quotas:      PUQ_AI_STANDARD_QUOTA    (AI domains, standard tier)
--                 PUQ_AI_HIGH_TIER_QUOTA   (AI domains, high tier - escalation)
--                 PUQ_WH_STANDARD_QUOTA    (warehouse, standard tier)
--    Procedures:  PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)
--                 PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()
--
--  SAFETY:
--    ⚠️  ALL quotas target PUQ_DEMO_USER ONLY (via INTERSECTION tags).
--    ⚠️  The currently logged-in user is NEVER modified, tagged, or blocked.
--    ⚠️  Complete teardown at the bottom removes every created object.
--
--  EXECUTION:
--    Run this file top-to-bottom in Snowsight as ACCOUNTADMIN.
--    Each phase can also be run independently.
--
-- =============================================================================


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 1: DATABASE, SCHEMAS, AND WAREHOUSE                                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

USE ROLE ACCOUNTADMIN;

-- Isolated governance database — all quota objects live here.
CREATE DATABASE IF NOT EXISTS PUQ_GOVERNANCE_DB
    COMMENT = 'Per-User Quota governance database — isolated test environment';

-- Schema for quota objects (SNOWFLAKE.CORE.QUOTA).
CREATE SCHEMA IF NOT EXISTS PUQ_GOVERNANCE_DB.QUOTAS
    COMMENT = 'Houses all per-user quota objects';

-- Schema for tags used in user scoping.
CREATE SCHEMA IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS
    COMMENT = 'Tags for per-user quota user scoping (cost_center, usage_tier, department)';

-- Schema for custom action and cycle-reset stored procedures.
CREATE SCHEMA IF NOT EXISTS PUQ_GOVERNANCE_DB.ACTIONS
    COMMENT = 'Stored procedures for quota custom actions and cycle-start resets';

-- Dedicated test warehouse (XSMALL to minimize cost).
CREATE WAREHOUSE IF NOT EXISTS PUQ_TEST_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Isolated XS warehouse for per-user quota testing — safe to suspend/resume';


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 2: RBAC — ROLES AND PRIVILEGE GRANTS                                 ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- QUOTA ADMIN ROLE: Creates, configures, and monitors quotas.
-- Follows least-privilege: only the permissions required for quota operations.
CREATE ROLE IF NOT EXISTS PUQ_QUOTA_ADMIN_ROLE
    COMMENT = 'Manages per-user quotas — create, configure, monitor, enforce';

-- TEST USER ROLE: Simulates a standard operational user.
CREATE ROLE IF NOT EXISTS PUQ_TEST_USER_ROLE
    COMMENT = 'Operational role for PUQ_DEMO_USER — standard platform access';

-- ── Grants to PUQ_QUOTA_ADMIN_ROLE ──────────────────────────────────────────────

-- Database and schema navigation.
GRANT USAGE ON DATABASE PUQ_GOVERNANCE_DB TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.TAGS TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.ACTIONS TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- SNOWFLAKE.QUOTA_CREATOR is the database role required to create quota objects.
GRANT DATABASE ROLE SNOWFLAKE.QUOTA_CREATOR TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- CREATE privilege on the quota schema (allows CREATE SNOWFLAKE.CORE.QUOTA).
GRANT CREATE SNOWFLAKE.CORE.QUOTA ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- CREATE privileges for tags and stored procedures.
GRANT CREATE TAG ON SCHEMA PUQ_GOVERNANCE_DB.TAGS TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT CREATE PROCEDURE ON SCHEMA PUQ_GOVERNANCE_DB.ACTIONS TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- Warehouse access for quota admin operations.
GRANT USAGE ON WAREHOUSE PUQ_TEST_WH TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- MANAGE GRANTS required for custom actions that ALTER USER.
GRANT MANAGE GRANTS ON ACCOUNT TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- ── Grants to PUQ_TEST_USER_ROLE ────────────────────────────────────────────────

GRANT USAGE ON WAREHOUSE PUQ_TEST_WH TO ROLE PUQ_TEST_USER_ROLE;
GRANT USAGE ON DATABASE PUQ_GOVERNANCE_DB TO ROLE PUQ_TEST_USER_ROLE;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS TO ROLE PUQ_TEST_USER_ROLE;

-- ── Role hierarchy ──────────────────────────────────────────────────────────────

-- Both custom roles roll up to ACCOUNTADMIN for administration.
GRANT ROLE PUQ_QUOTA_ADMIN_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE PUQ_TEST_USER_ROLE TO ROLE ACCOUNTADMIN;


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 3: DEDICATED TEST USER                                                ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- ⚠️  THIS IS THE ONLY USER THAT QUOTAS ARE APPLIED TO.
-- ⚠️  THE CURRENTLY LOGGED-IN USER (SATISH) IS NEVER TOUCHED.

CREATE USER IF NOT EXISTS PUQ_DEMO_USER
    PASSWORD = 'PuqDemo2026!SecureTemp'
    DEFAULT_ROLE = 'PUQ_TEST_USER_ROLE'
    DEFAULT_WAREHOUSE = 'PUQ_TEST_WH'
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Dedicated per-user quota test user — SAFE TO DISABLE/BLOCK/TAG';

-- Assign operational role to the test user.
GRANT ROLE PUQ_TEST_USER_ROLE TO USER PUQ_DEMO_USER;

-- Set email (required for notifications — must be verified in production).
ALTER USER PUQ_DEMO_USER SET EMAIL = 'puq-demo-user@example.com';


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 4: TAGS FOR USER SCOPING                                              ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Tags enable dynamic user resolution at evaluation time.
-- Changes to tags are automatically reflected without quota reconfiguration.
-- Note: TAG_REFERENCES can lag ~2 hours for scope resolution.

USE SCHEMA PUQ_GOVERNANCE_DB.TAGS;

-- COST_CENTER: Maps users to business cost centers.
CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.COST_CENTER
    ALLOWED_VALUES 'engineering', 'analytics', 'finance', 'marketing', 'executive'
    COMMENT = 'Business cost center for quota scoping and chargeback';

-- USAGE_TIER: Differentiates user spending tiers within a cost center.
-- Used with INTERSECTION to create non-overlapping user groups per quota.
CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER
    ALLOWED_VALUES 'sandbox', 'standard', 'high', 'executive', 'unlimited'
    COMMENT = 'Usage tier — determines which quota (and limit) governs the user';

-- DEPARTMENT: Organizational department for reporting and cross-functional governance.
CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT
    ALLOWED_VALUES 'data-science', 'platform-engineering', 'product', 'operations', 'leadership'
    COMMENT = 'Department assignment for cross-functional governance and reporting';

-- ── APPLYBUDGET privilege on each tag (required for SET_USER_TAGS) ───────────────
-- Per docs: "The role used to set user tags on a quota must have APPLYBUDGET on each tag."
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.COST_CENTER TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- ── Apply tags ONLY to the dedicated test user ──────────────────────────────────
-- Standard tier engineering user — will be governed by the standard quota.
ALTER USER PUQ_DEMO_USER SET TAG
    PUQ_GOVERNANCE_DB.TAGS.COST_CENTER = 'engineering',
    PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'standard',
    PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT = 'data-science';

-- Verify tag assignment.
SELECT
    SYSTEM$GET_TAG('PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'PUQ_DEMO_USER', 'USER') AS TAG_COST_CENTER,
    SYSTEM$GET_TAG('PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'PUQ_DEMO_USER', 'USER') AS TAG_USAGE_TIER,
    SYSTEM$GET_TAG('PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT', 'PUQ_DEMO_USER', 'USER') AS TAG_DEPARTMENT;


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 5: CUSTOM ACTION STORED PROCEDURES                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Custom actions must:
--   1. Use EXECUTE AS OWNER (registration is rejected otherwise)
--   2. Be granted USAGE to the SNOWFLAKE application
--   3. Accept a VARCHAR first argument (JSON array of user IDs who breached)

USE ROLE ACCOUNTADMIN;
USE SCHEMA PUQ_GOVERNANCE_DB.ACTIONS;

-- ── Custom Action: Disable users who breach 100% of their quota ─────────────────
-- The quota engine passes '[user_id_1, user_id_2, ...]' as the first argument.
-- This procedure resolves each user_id to a username and disables them.
CREATE OR REPLACE PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(user_ids VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    arr        VARIANT := PARSE_JSON(:user_ids);
    i          INT     := 0;
    cnt        INT     := ARRAY_SIZE(:arr);
    v_user_id  VARCHAR;
    v_user_name VARCHAR;
    v_sql      VARCHAR;
    v_disabled INT     := 0;
    v_skipped  INT     := 0;
BEGIN
    WHILE (i < cnt) DO
        v_user_id := :arr[:i]::VARCHAR;
        v_user_name := NULL;

        -- Resolve numeric user_id to the username via account_usage.users.
        SELECT name INTO :v_user_name
        FROM   snowflake.account_usage.users
        WHERE  user_id    = :v_user_id
          AND  deleted_on IS NULL
        LIMIT 1;

        IF (v_user_name IS NOT NULL) THEN
            v_sql := 'ALTER USER ' || :v_user_name || ' SET DISABLED = TRUE';
            EXECUTE IMMEDIATE :v_sql;
            v_disabled := v_disabled + 1;
        ELSE
            v_skipped := v_skipped + 1;
        END IF;
        i := i + 1;
    END WHILE;

    RETURN 'Result: disabled=' || :v_disabled
        || ', skipped_not_found=' || :v_skipped
        || ', total_processed=' || :cnt;
END;
$$;

-- REQUIRED: Grant USAGE to the SNOWFLAKE application so the quota engine can invoke it.
GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)
    TO APPLICATION SNOWFLAKE;


-- ── Cycle-Start Reset: Re-enable users at the beginning of each UTC month ───────
-- Only re-enables the test user (safety guard against production impact).
CREATE OR REPLACE PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_user_name VARCHAR;
    v_count     INT := 0;
    c_disabled CURSOR FOR
        SELECT name
        FROM   snowflake.account_usage.users
        WHERE  disabled   = 'true'
          AND  deleted_on IS NULL
          AND  name       = 'PUQ_DEMO_USER';
BEGIN
    FOR rec IN c_disabled DO
        v_user_name := rec.name;
        EXECUTE IMMEDIATE 'ALTER USER ' || :v_user_name || ' SET DISABLED = FALSE';
        v_count := v_count + 1;
    END FOR;

    RETURN 'Cycle-start reset complete. Users re-enabled: ' || :v_count;
END;
$$;

-- REQUIRED: Grant USAGE to the SNOWFLAKE application.
GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()
    TO APPLICATION SNOWFLAKE;


-- Grant APPLICATION SNOWFLAKE access to database/schema (required for custom action invocation).
GRANT USAGE ON DATABASE PUQ_GOVERNANCE_DB TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.ACTIONS TO APPLICATION SNOWFLAKE;

-- Transfer procedure ownership to quota admin role (quota owner must be able to invoke).
GRANT OWNERSHIP ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)
    TO ROLE PUQ_QUOTA_ADMIN_ROLE REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()
    TO ROLE PUQ_QUOTA_ADMIN_ROLE REVOKE CURRENT GRANTS;

-- Re-grant USAGE to APPLICATION SNOWFLAKE after ownership transfer.
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)
    TO APPLICATION SNOWFLAKE;
GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()
    TO APPLICATION SNOWFLAKE;


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 6: QUOTA CREATION AND CONFIGURATION                                   ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Architecture:
--   • AI and warehouse domains CANNOT be combined (different credit units)
--   • Block enforcement supports ONLY AI domains (not warehouses)
--   • Multiple quotas can cover the same user (each evaluated independently)
--   • INTERSECTION mode creates non-overlapping groups for tiered escalation

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  QUOTA 1: AI STANDARD TIER                                                     │
-- │  Domains: AI Functions, Cortex Agents, Snowflake CoWork, Snowflake CoCo     │
-- │  Enforcement: Block (built-in, evaluates within minutes)                     │
-- │  Users: cost_center=engineering AND usage_tier=standard                       │
-- │  Limits: 100 AI credits/month, 10 AI credits/day                            │
-- └─────────────────────────────────────────────────────────────────────────────┘

CREATE SNOWFLAKE.CORE.QUOTA PUQ_AI_STANDARD_QUOTA();

-- Add all AI domains to monitoring.
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');

-- Scope: INTERSECTION of cost_center=engineering AND usage_tier=standard.
-- User must match ALL specified tags to be in scope.
CALL PUQ_AI_STANDARD_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'standard']
    ],
    'INTERSECTION'
);

-- Monthly per-user limit: 100 AI credits.
CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(100);

-- Daily per-user limit: 10 AI credits (resets at UTC midnight).
CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(10, 'DAILY');

-- Enable block enforcement: automatically deny AI requests when limit is reached.
-- Enforcement evaluates within minutes of a spend event (separate from eval task).
CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Note: SET_REFRESH_TIER('TIER_1H') is deprecated as of Aug 2026.
-- Snowflake now provides low-latency evaluation by default at no extra cost.
-- CALL PUQ_AI_STANDARD_QUOTA!SET_REFRESH_TIER('TIER_1H');


-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  QUOTA 2: AI HIGH TIER (ESCALATION TARGET)                                   │
-- │  Domains: Same AI domains                                                    │
-- │  Enforcement: Block (built-in)                                               │
-- │  Users: cost_center=engineering AND usage_tier=high                           │
-- │  Limits: 500 AI credits/month, 50 AI credits/day                            │
-- │                                                                              │
-- │  PURPOSE: When a standard-tier user needs more headroom, change their        │
-- │  usage_tier tag to 'high'. They move out of standard quota scope into        │
-- │  high-tier scope. Blocks from standard quota clear within ~15 minutes.       │
-- └─────────────────────────────────────────────────────────────────────────────┘

CREATE SNOWFLAKE.CORE.QUOTA PUQ_AI_HIGH_TIER_QUOTA();

CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');

-- Scope: engineering cost center with HIGH usage tier.
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'high']
    ],
    'INTERSECTION'
);

-- Higher limits for escalated users.
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_PER_USER_LIMIT(500);
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_PER_USER_LIMIT(50, 'DAILY');

CALL PUQ_AI_HIGH_TIER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);
-- CALL PUQ_AI_HIGH_TIER_QUOTA!SET_REFRESH_TIER('TIER_1H');  -- Deprecated


-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  QUOTA 3: WAREHOUSE STANDARD TIER                                            │
-- │  Domains: WAREHOUSE (PUQ_TEST_WH)                                           │
-- │  Enforcement: Custom action ONLY (block enforcement does NOT apply)          │
-- │  Users: cost_center=engineering AND usage_tier=standard                       │
-- │  Limits: 50 warehouse credits/month, 5 credits/day                          │
-- └─────────────────────────────────────────────────────────────────────────────┘

CREATE SNOWFLAKE.CORE.QUOTA PUQ_WH_STANDARD_QUOTA();

-- Add the specific test warehouse to monitoring.
CALL PUQ_WH_STANDARD_QUOTA!ADD_SHARED_RESOURCE(
    'WAREHOUSE',
    (SELECT SYSTEM$REFERENCE('WAREHOUSE', 'PUQ_TEST_WH'))
);

-- Same scope as AI standard quota (engineering + standard tier).
CALL PUQ_WH_STANDARD_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
        [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'standard']
    ],
    'INTERSECTION'
);

-- Monthly: 50 warehouse credits | Daily: 5 credits.
CALL PUQ_WH_STANDARD_QUOTA!SET_PER_USER_LIMIT(50);
CALL PUQ_WH_STANDARD_QUOTA!SET_PER_USER_LIMIT(5, 'DAILY');


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 7: NOTIFICATIONS                                                       ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Threshold types:
--   PROJECTED: Triggers on extrapolated spend to month-end (early warning).
--              Sent at most once per threshold per user within 24 hours.
--   ACTUAL:    Triggers on accumulated spend (hard enforcement signal).
--              Sent at most once per user per quota cycle.
--
-- The third argument (TRUE/FALSE) controls whether the USER gets notified.

-- ── AI Standard Quota: 4-tier progressive notifications ─────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(50, 'PROJECTED', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(90, 'ACTUAL', TRUE);
CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE);

-- Admin summary emails: sent after evaluation when new breaches are detected.
CALL PUQ_AI_STANDARD_QUOTA!SET_ADMIN_EMAILS('puq-admin@example.com');

-- ── AI High Tier Quota: lighter notifications (trusted users) ───────────────────
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
CALL PUQ_AI_HIGH_TIER_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE);
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_ADMIN_EMAILS('puq-admin@example.com');

-- ── Warehouse Standard Quota: progressive notifications ─────────────────────────
CALL PUQ_WH_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(60, 'PROJECTED', TRUE);
CALL PUQ_WH_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
CALL PUQ_WH_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE);
CALL PUQ_WH_STANDARD_QUOTA!SET_ADMIN_EMAILS('puq-admin@example.com');


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 8: CUSTOM ACTIONS (WAREHOUSE QUOTA)                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Block enforcement does NOT apply to warehouses.
-- For warehouse governance, use custom actions instead.

-- Register DISABLE_USERS_BY_ID at 100% actual spend.
CALL PUQ_WH_STANDARD_QUOTA!ADD_CUSTOM_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)'),
    ARRAY_CONSTRUCT(),
    'ACTUAL',
    100
);

-- Register the cycle-start reset action (runs once each UTC month start).
-- Re-enables any users disabled by the custom action above.
CALL PUQ_WH_STANDARD_QUOTA!SET_CYCLE_START_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()'),
    []
);

-- Verify the quota's owner role can invoke the configured procedures.
CALL PUQ_WH_STANDARD_QUOTA!CONFIRM_CUSTOM_ACTIONS_ACCESS();


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 9: DEPLOYMENT VERIFICATION                                             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- ── Configuration audit ─────────────────────────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_CONFIG();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_CONFIG();
CALL PUQ_WH_STANDARD_QUOTA!GET_CONFIG();

-- ── User scope validation ───────────────────────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_QUOTA_SCOPE();
CALL PUQ_AI_STANDARD_QUOTA!GET_USERS();

-- ── Notification validation ─────────────────────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();
CALL PUQ_WH_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();

-- ── Custom action validation ────────────────────────────────────────────────────
CALL PUQ_WH_STANDARD_QUOTA!GET_CUSTOM_ACTIONS();
CALL PUQ_WH_STANDARD_QUOTA!GET_CYCLE_START_ACTION();

-- ── Enforcement status ──────────────────────────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_ACTIVE_BLOCKS();


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 10: MONITORING AND REPORTING QUERIES                                   ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- These queries demonstrate how to build dashboards from quota data.

-- ── Near-real-time AI usage preview (~2h delay) ─────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_PER_USER_USAGE_PREVIEW(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ── Finalized spending for the current month ────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ── Warehouse spending details ──────────────────────────────────────────────────
CALL PUQ_WH_STANDARD_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ── Enforcement history (current month) ─────────────────────────────────────────
CALL PUQ_AI_STANDARD_QUOTA!GET_ENFORCEMENT_HISTORY(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ── Event table: all quota events in the last 7 days ────────────────────────────
USE ROLE ACCOUNTADMIN;
SELECT
    TIMESTAMP,
    RECORD:name::STRING            AS EVENT_NAME,
    RECORD:severity_text::STRING   AS SEVERITY,
    VALUE:message::STRING          AS MESSAGE,
    RESOURCE_ATTRIBUTES
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC
LIMIT 50;

-- ── Block history from account_usage view ───────────────────────────────────────
SELECT *
FROM snowflake.account_usage.quota_access_block_history
WHERE CREATED_ON > DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY CREATED_ON DESC
LIMIT 50;


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 11: ESCALATION DEMONSTRATION                                           ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Shows how to move a user from standard to high tier quota when blocked.
-- This pattern gives immediate relief without raising limits for everyone.

-- To escalate PUQ_DEMO_USER to high tier (when blocked):
-- ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'high';
-- The pipeline clears standard-tier blocks (~15 min) and evaluates against high-tier limit.

-- To de-escalate back to standard tier:
-- ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'standard';


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 12: EXCLUDE_USERS DEMONSTRATION                                        ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Per docs: "Keep all users in scope but exclude those matching given tags."
-- This demonstrates how to exempt specific users from a quota.
-- (Commented out to avoid conflicting with the INTERSECTION scope above.)

-- Example: To create a quota that monitors ALL users EXCEPT 'unlimited' tier:
-- CREATE SNOWFLAKE.CORE.QUOTA PUQ_AI_ALL_EXCEPT_UNLIMITED_QUOTA();
-- CALL PUQ_AI_ALL_EXCEPT_UNLIMITED_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
-- CALL PUQ_AI_ALL_EXCEPT_UNLIMITED_QUOTA!EXCLUDE_USERS('TAG', [
--     [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'unlimited']
-- ]);
-- CALL PUQ_AI_ALL_EXCEPT_UNLIMITED_QUOTA!SET_PER_USER_LIMIT(200);


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  DEPLOYMENT SUMMARY                                                           ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

SELECT '=== DEPLOYMENT COMPLETE ===' AS STATUS;
SELECT
    'PUQ_AI_STANDARD_QUOTA'  AS QUOTA_NAME,
    'AI FUNCTION, CORTEX AGENT, SNOWFLAKE INTELLIGENCE, CORTEX CODE' AS DOMAINS,
    '100/month, 10/day'      AS LIMITS,
    'BLOCK (built-in)'       AS ENFORCEMENT,
    'TIER_1H'                AS REFRESH,
    'engineering + standard'  AS SCOPE
UNION ALL SELECT
    'PUQ_AI_HIGH_TIER_QUOTA',
    'AI FUNCTION, CORTEX AGENT, SNOWFLAKE INTELLIGENCE, CORTEX CODE',
    '500/month, 50/day',
    'BLOCK (built-in)',
    'TIER_1H',
    'engineering + high'
UNION ALL SELECT
    'PUQ_WH_STANDARD_QUOTA',
    'WAREHOUSE (PUQ_TEST_WH)',
    '50/month, 5/day',
    'Custom Action (disable user)',
    'Default (~6h)',
    'engineering + standard';


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  COMPLETE TEARDOWN (Run when finished testing)                                ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
-- Uncomment and execute the block below to remove ALL created objects.

-- USE ROLE PUQ_QUOTA_ADMIN_ROLE;
-- USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
-- CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);
-- CALL PUQ_AI_HIGH_TIER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE);
-- CALL PUQ_WH_STANDARD_QUOTA!REMOVE_CUSTOM_ACTIONS();
-- CALL PUQ_WH_STANDARD_QUOTA!REMOVE_CYCLE_START_ACTION();

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
-- SELECT 'TEARDOWN COMPLETE — All PUQ objects removed' AS STATUS
-- PUQ Enforcement: Block Enforcement and Custom Actions
-- =============================================================================
-- Two enforcement mechanisms:
--   1. Block (built-in): AI domains only, evaluates within minutes, auto-resets.
--   2. Custom Action: Stored procedure executes when threshold crossed.
--
-- Key constraints:
--   - Block enforcement supports ONLY AI domains (not warehouses)
--   - Custom actions must use EXECUTE AS OWNER
--   - Custom actions must be granted USAGE to APPLICATION SNOWFLAKE
--   - Custom actions receive JSON array of user IDs as first argument
--
-- ROLE REQUIRED: ACCOUNTADMIN (for procedure creation), PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCK ENFORCEMENT (AI Quotas)
-- Runs on Snowflake infrastructure (no customer credit cost).
-- Evaluates within minutes. Auto-releases at cycle boundary.
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- Enable block enforcement on AI standard quota.
CALL PUQ_AI_STANDARD_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Enable block enforcement on AI high-tier quota.
CALL PUQ_AI_HIGH_TIER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Check who is currently blocked.
CALL PUQ_AI_STANDARD_QUOTA!GET_ACTIVE_BLOCKS();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_ACTIVE_BLOCKS();

-- Enforcement history for the current month.
CALL PUQ_AI_STANDARD_QUOTA!GET_ENFORCEMENT_HISTORY(
    TO_VARCHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM-DD'),
    TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD')
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUSTOM ACTION: Disable users at 100% actual spend (Warehouse Quota)
-- Since block enforcement does NOT apply to warehouses, use custom action.
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;
USE SCHEMA PUQ_GOVERNANCE_DB.ACTIONS;

-- Stored procedure: receives JSON array of user IDs who breached threshold.
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
    RETURN 'disabled=' || :v_disabled || ', skipped=' || :v_skipped || ', total=' || :cnt;
END;
$$;

-- REQUIRED: Grant to SNOWFLAKE application.
GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)
    TO APPLICATION SNOWFLAKE;

-- Register as custom action at 100% actual spend on warehouse quota.
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

CALL PUQ_WH_STANDARD_QUOTA!ADD_CUSTOM_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)'),
    ARRAY_CONSTRUCT(),
    'ACTUAL',
    100
);

-- Verify registration.
CALL PUQ_WH_STANDARD_QUOTA!GET_CUSTOM_ACTIONS();
CALL PUQ_WH_STANDARD_QUOTA!CONFIRM_CUSTOM_ACTIONS_ACCESS();

-- ═══════════════════════════════════════════════════════════════════════════════
-- CYCLE-START RESET ACTION: Re-enable disabled users at month boundary
-- ═══════════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;
USE SCHEMA PUQ_GOVERNANCE_DB.ACTIONS;

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
        SELECT name FROM snowflake.account_usage.users
        WHERE disabled = 'true' AND deleted_on IS NULL AND name = 'PUQ_DEMO_USER';
BEGIN
    FOR rec IN c_disabled DO
        v_user_name := rec.name;
        EXECUTE IMMEDIATE 'ALTER USER ' || :v_user_name || ' SET DISABLED = FALSE';
        v_count := v_count + 1;
    END FOR;
    RETURN 'Cycle-start reset. Re-enabled: ' || :v_count;
END;
$$;

GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()
    TO APPLICATION SNOWFLAKE;

-- Register on warehouse quota.
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

CALL PUQ_WH_STANDARD_QUOTA!SET_CYCLE_START_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()'),
    []
);

CALL PUQ_WH_STANDARD_QUOTA!GET_CYCLE_START_ACTION();

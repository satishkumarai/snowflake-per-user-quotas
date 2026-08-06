-- PUQ 07: Custom Actions and Cycle-Start Reset
-- =============================================================================
-- Custom action requirements:
--   1. EXECUTE AS OWNER (registration rejected otherwise)
--   2. GRANT USAGE TO APPLICATION SNOWFLAKE
--   3. First argument = JSON array of breaching user IDs
-- ROLE REQUIRED: ACCOUNTADMIN (for GRANT TO APPLICATION), PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PUQ_GOVERNANCE_DB.ACTIONS;

-- ── Custom Action: Disable users at 100% actual spend ────────────────────────
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

GRANT USAGE ON PROCEDURE PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)
    TO APPLICATION SNOWFLAKE;

-- ── Cycle-Start Reset: Re-enable PUQ_DEMO_USER at month start ────────────────
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

-- ── Grant APPLICATION SNOWFLAKE access to the database and schema ─────────────
-- Required for the quota engine to resolve and invoke the procedure.
GRANT USAGE ON DATABASE PUQ_GOVERNANCE_DB TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.ACTIONS TO APPLICATION SNOWFLAKE;

-- ── Transfer procedure ownership to quota admin role ─────────────────────────
-- The quota's owner role must be able to invoke the procedure.
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

-- ── Register on PUQ_WH_STANDARD_QUOTA ────────────────────────────────────────
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

CALL PUQ_WH_STANDARD_QUOTA!ADD_CUSTOM_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'PUQ_GOVERNANCE_DB.ACTIONS.DISABLE_USERS_BY_ID(VARCHAR)'),
    ARRAY_CONSTRUCT(),
    'ACTUAL',
    100
);

CALL PUQ_WH_STANDARD_QUOTA!SET_CYCLE_START_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'PUQ_GOVERNANCE_DB.ACTIONS.REENABLE_QUOTA_USERS()'),
    []
);

-- Verify.
CALL PUQ_WH_STANDARD_QUOTA!GET_CUSTOM_ACTIONS();
CALL PUQ_WH_STANDARD_QUOTA!CONFIRM_CUSTOM_ACTIONS_ACCESS();
CALL PUQ_WH_STANDARD_QUOTA!GET_CYCLE_START_ACTION();

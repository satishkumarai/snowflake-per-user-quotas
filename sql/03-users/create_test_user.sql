-- PUQ 03: Dedicated Test User Creation
-- =============================================================================
-- Creates PUQ_DEMO_USER — the ONLY user quotas are applied to.
-- The currently logged-in user is NEVER modified.
-- ROLE REQUIRED: ACCOUNTADMIN
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS PUQ_DEMO_USER
    PASSWORD = 'PuqDemo2026!SecureTemp'
    DEFAULT_ROLE = 'PUQ_TEST_USER_ROLE'
    DEFAULT_WAREHOUSE = 'PUQ_TEST_WH'
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Dedicated PUQ test user — SAFE TO DISABLE/BLOCK/TAG';

-- Assign operational role.
GRANT ROLE PUQ_TEST_USER_ROLE TO USER PUQ_DEMO_USER;

-- Set email (required for notifications — must be verified in production).
ALTER USER PUQ_DEMO_USER SET EMAIL = 'puq-demo-user@example.com';

-- Verify.
DESCRIBE USER PUQ_DEMO_USER;

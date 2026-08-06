-- PUQ 01: Prerequisites — Database, Schemas, and Warehouse
-- =============================================================================
-- Creates the isolated PUQ governance infrastructure.
-- SAFETY: All objects use the PUQ_ prefix. No existing objects are modified.
-- IDEMPOTENT: Uses CREATE ... IF NOT EXISTS.
-- ROLE REQUIRED: ACCOUNTADMIN
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Isolated governance database — all PUQ quota objects live here.
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
    COMMENT = 'Isolated XS warehouse for per-user quota testing';

-- Verify.
SHOW DATABASES LIKE 'PUQ_GOVERNANCE_DB';
SHOW SCHEMAS IN DATABASE PUQ_GOVERNANCE_DB;
SHOW WAREHOUSES LIKE 'PUQ_TEST_WH';

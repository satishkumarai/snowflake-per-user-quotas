-- =====================================================================
-- 00_setup_database_and_roles.sql
-- Foundation for the per-user quota implementation.
-- Creates the governance database, tag schema, quota schema, and the
-- roles used for quota administration and role-based scoping.
-- =====================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS PUQ_GOVERNANCE_DB;

-- Tags for business-attribute scoping (cost center, usage tier)
CREATE SCHEMA IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS;

-- Schema that holds the quota instances
CREATE SCHEMA IF NOT EXISTS PUQ_GOVERNANCE_DB.QUOTAS;

USE SCHEMA PUQ_GOVERNANCE_DB.TAGS;

CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.COST_CENTER
    ALLOWED_VALUES 'engineering', 'analytics', 'finance'
    COMMENT = 'Cost center used for quota scoping and chargeback';

CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER
    ALLOWED_VALUES 'standard', 'high', 'executive'
    COMMENT = 'Usage tier used for quota scoping';

-- Roles selected by the role-based quota scope. Users holding these
-- roles directly are resolved into the quota population.
CREATE ROLE IF NOT EXISTS ANALYST COMMENT = 'Analyst functional role';
CREATE ROLE IF NOT EXISTS DATA_ENG COMMENT = 'Data engineer functional role';
CREATE ROLE IF NOT EXISTS DATA_STEWARD COMMENT = 'Data steward functional role';
CREATE ROLE IF NOT EXISTS CONTRACTOR_RL COMMENT = 'Contractor functional role';

-- Test user used by the override example (lower weekly limit)
CREATE USER IF NOT EXISTS CONTRACTOR_BOB PASSWORD = 'TempPwd#123' MUST_CHANGE_PASSWORD = TRUE;
GRANT ROLE DATA_ENG TO USER CONTRACTOR_BOB;

-- Quota administration role: receives the ADMIN instance role on each quota
CREATE ROLE IF NOT EXISTS QUOTA_ADMIN
    COMMENT = 'Administers per-user quota instances in PUQ_GOVERNANCE_DB.QUOTAS';

GRANT USAGE ON DATABASE PUQ_GOVERNANCE_DB TO ROLE QUOTA_ADMIN;
GRANT USAGE ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS TO ROLE QUOTA_ADMIN;
GRANT CREATE SNOWFLAKE.CORE.QUOTA ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS TO ROLE QUOTA_ADMIN;
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.COST_CENTER TO ROLE QUOTA_ADMIN;
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER TO ROLE QUOTA_ADMIN;

GRANT ROLE QUOTA_ADMIN TO ROLE SYSADMIN;

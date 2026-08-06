-- PUQ 04: Tags for User Scoping
-- =============================================================================
-- Tags enable dynamic user resolution at evaluation time.
-- Changes to tags are automatically reflected without quota reconfiguration.
-- Note: TAG_REFERENCES can lag ~2 hours for scope resolution.
-- ROLE REQUIRED: ACCOUNTADMIN
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PUQ_GOVERNANCE_DB.TAGS;

-- COST_CENTER: Maps users to business cost centers.
CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.COST_CENTER
    ALLOWED_VALUES 'engineering', 'analytics', 'finance', 'marketing', 'executive'
    COMMENT = 'Business cost center for PUQ scoping and chargeback';

-- USAGE_TIER: Differentiates user spending tiers.
CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER
    ALLOWED_VALUES 'sandbox', 'standard', 'high', 'executive', 'unlimited'
    COMMENT = 'Usage tier — determines which PUQ quota governs the user';

-- DEPARTMENT: Organizational department.
CREATE TAG IF NOT EXISTS PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT
    ALLOWED_VALUES 'data-science', 'platform-engineering', 'product', 'operations', 'leadership'
    COMMENT = 'Department for cross-functional governance and reporting';

-- APPLYBUDGET privilege (required for SET_USER_TAGS on quotas).
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.COST_CENTER TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT APPLYBUDGET ON TAG PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT TO ROLE PUQ_QUOTA_ADMIN_ROLE;

-- Apply tags ONLY to PUQ_DEMO_USER.
ALTER USER PUQ_DEMO_USER SET TAG
    PUQ_GOVERNANCE_DB.TAGS.COST_CENTER = 'engineering',
    PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'standard',
    PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT = 'data-science';

-- Verify.
SELECT
    SYSTEM$GET_TAG('PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'PUQ_DEMO_USER', 'USER') AS COST_CENTER,
    SYSTEM$GET_TAG('PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'PUQ_DEMO_USER', 'USER') AS USAGE_TIER,
    SYSTEM$GET_TAG('PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT', 'PUQ_DEMO_USER', 'USER') AS DEPARTMENT;

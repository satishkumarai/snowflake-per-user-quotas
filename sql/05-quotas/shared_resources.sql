-- PUQ 05b: Shared Resources — Domain-level and resource-level examples
-- =============================================================================
-- Demonstrates all documented ways to add monitored domains to a quota.
-- Per docs: A single quota monitors EITHER warehouse OR AI domains (not both).
--
-- Documented ADD_SHARED_RESOURCE patterns:
--   ADD_SHARED_RESOURCE('<domain>')                        — entire domain
--   ADD_SHARED_RESOURCE('<domain>', '<specific_resource>') — specific resource
--   ADD_SHARED_RESOURCE('<domain>', (SELECT SYSTEM$REFERENCE(...))) — by reference
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ═══════════════════════════════════════════════════════════════════════════════
-- AI DOMAINS (can be combined together in one quota)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Add the entire AI Function domain (covers all AI functions).
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');

-- Add a specific AI function only (e.g., AI_CLASSIFY).
-- Note: If you already added the whole AI FUNCTION domain, this is unnecessary.
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_CLASSIFY');

-- Add the Cortex Agent domain.
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');

-- Add a specific Cortex Agent by reference.
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE(
--     'CORTEX AGENT',
--     (SELECT SYSTEM$REFERENCE('CORTEX AGENT', 'my_agent_name'))
-- );

-- Add Snowflake CoWork (formerly Snowflake Intelligence).
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');

-- Add Snowflake CoCo (formerly Cortex Code).
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');

-- ═══════════════════════════════════════════════════════════════════════════════
-- WAREHOUSE DOMAIN (must be in a SEPARATE quota from AI domains)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Add a specific warehouse by reference.
-- CALL PUQ_WH_STANDARD_QUOTA!ADD_SHARED_RESOURCE(
--     'WAREHOUSE',
--     (SELECT SYSTEM$REFERENCE('WAREHOUSE', 'PUQ_TEST_WH'))
-- );

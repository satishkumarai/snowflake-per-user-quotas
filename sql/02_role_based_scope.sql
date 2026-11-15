-- =====================================================================
-- 02_role_based_scope.sql
-- Role-based user scoping (GA Nov 11, 2026): SET_QUOTA_USER_SCOPE,
-- ADD_QUOTA_USER_SCOPE, REMOVE_QUOTA_USER_SCOPE, GET_QUOTA_SCOPE_V2.
--
-- Scope resolution order (fixed by Snowflake):
--   1. applies_to           (include: ALL_USERS or GROUP_OF_USERS)
--   2. excluded_by.user_tags
--   3. excluded_by.roles
--   4. usernames (excluded removed, then included added)
--
-- Important: roles select users with a DIRECT grant only. Inherited
-- role grants do not count. Resolved scope updates ~10-15 minutes
-- after role/tag changes.
-- =====================================================================

USE ROLE QUOTA_ADMIN;

-- ---------------------------------------------------------------------
-- AI quota: users directly granted ANALYST or DATA_ENG,
-- excluding ACCOUNTADMIN. Always pass operator explicitly - omitting
-- it resets the operator to UNION.
-- ---------------------------------------------------------------------
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!SET_QUOTA_USER_SCOPE(
    PARSE_JSON('{
        "applies_to": {
            "type": "GROUP_OF_USERS",
            "operator": "UNION",
            "roles": ["ANALYST", "DATA_ENG"]
        },
        "excluded_by": {
            "roles": ["ACCOUNTADMIN"]
        }
    }')
);

-- ---------------------------------------------------------------------
-- Warehouse quota: engineering users who also carry the standard
-- usage-tier tag -> INTERSECTION. Tags must be passed via
-- SYSTEM$REFERENCE, so build the payload with OBJECT_CONSTRUCT.
-- ---------------------------------------------------------------------
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!SET_QUOTA_USER_SCOPE(
    OBJECT_CONSTRUCT(
        'applies_to', OBJECT_CONSTRUCT(
            'type', 'GROUP_OF_USERS',
            'operator', 'INTERSECTION',
            'user_tags', ARRAY_CONSTRUCT(
                ARRAY_CONSTRUCT(
                    SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET'),
                    'standard'
                )
            ),
            'roles', ARRAY_CONSTRUCT('DATA_ENG')
        ),
        'excluded_by', OBJECT_CONSTRUCT(
            'roles', ARRAY_CONSTRUCT('ACCOUNTADMIN')
        )
    )
);

-- ---------------------------------------------------------------------
-- Incremental changes: ADD / REMOVE do not accept type or operator.
-- ---------------------------------------------------------------------

-- Add a role to the include part (tags and operator unchanged)
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADD_QUOTA_USER_SCOPE(
    PARSE_JSON('{"applies_to": {"roles": ["DATA_STEWARD"]}}')
);

-- Add a role to the exclusions
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!ADD_QUOTA_USER_SCOPE(
    PARSE_JSON('{"excluded_by": {"roles": ["CONTRACTOR_RL"]}}')
);

-- Remove that role and a named user from the exclusions
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!REMOVE_QUOTA_USER_SCOPE(
    PARSE_JSON('{
        "excluded_by": {"roles": ["CONTRACTOR_RL"]},
        "usernames": {"excluded": ["BOB"]}
    }')
);

-- ---------------------------------------------------------------------
-- Named-user exception: keep one admin in scope despite the
-- ACCOUNTADMIN exclusion. usernames are applied last, so the named
-- include wins over the role exclusion.
-- ---------------------------------------------------------------------
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_AI_STANDARD_QUOTA!SET_QUOTA_USER_SCOPE(
    PARSE_JSON('{"usernames": {"included": ["ALICE"]}}')
);

-- Validation limits worth remembering:
--   * SET_QUOTA_USER_SCOPE: max 250 roles total (existing + new)
--   * ADD_QUOTA_USER_SCOPE: max 20 tags per call, no role limit
--   * PUBLIC role, nonexistent roles, and tags passed by name are rejected
--   * A rejected call leaves the stored scope unchanged

-- =====================================================================
-- 05_migrate_legacy_scope.sql
-- Migrates a legacy tag-only scope (SET_USER_TAGS / INCLUDE_USERS /
-- EXCLUDE_USERS / GET_QUOTA_SCOPE) to the new scope methods while
-- preserving the existing inclusion logic.
--
-- Legacy methods still work, but they cannot select or exclude users
-- by role. Use the new methods for full scope management.
-- =====================================================================

USE ROLE QUOTA_ADMIN;

-- ---------------------------------------------------------------------
-- BEFORE (legacy): engineering + standard tier via INTERSECTION
-- ---------------------------------------------------------------------
-- CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!SET_USER_TAGS(
--     [
--         [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'engineering'],
--         [(SELECT SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET')), 'standard']
--     ],
--     'INTERSECTION'
-- );

-- ---------------------------------------------------------------------
-- AFTER (new methods): identical tag logic expressed with
-- SET_QUOTA_USER_SCOPE. OBJECT_CONSTRUCT is required because
-- SYSTEM$REFERENCE is a SQL expression, not a JSON literal.
-- ---------------------------------------------------------------------
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!SET_QUOTA_USER_SCOPE(
    OBJECT_CONSTRUCT(
        'applies_to', OBJECT_CONSTRUCT(
            'type', 'GROUP_OF_USERS',
            'operator', 'INTERSECTION',
            'user_tags', ARRAY_CONSTRUCT(
                ARRAY_CONSTRUCT(
                    SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.COST_CENTER', 'SESSION', 'APPLYBUDGET'),
                    'engineering'
                ),
                ARRAY_CONSTRUCT(
                    SYSTEM$REFERENCE('TAG', 'PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER', 'SESSION', 'APPLYBUDGET'),
                    'standard'
                )
            )
        )
    )
);

-- ---------------------------------------------------------------------
-- Legacy -> new method mapping
-- ---------------------------------------------------------------------
-- SET_USER_TAGS(tags, 'UNION'/'INTERSECTION')
--     -> SET_QUOTA_USER_SCOPE with applies_to GROUP_OF_USERS + operator + user_tags
-- SET_USER_TAGS([], 'ALL_USERS')
--     -> SET_QUOTA_USER_SCOPE with applies_to ALL_USERS
--        (new call also clears include roles but KEEPS tag exclusions and
--         named users; pass empty lists to clear those too)
-- EXCLUDE_USERS('TAG', tags)
--     -> SET_QUOTA_USER_SCOPE with excluded_by.user_tags
-- INCLUDE_USERS(names) / EXCLUDE_USERS('USER', names)
--     -> ADD_QUOTA_USER_SCOPE with usernames.included / .excluded
--     -> SET_QUOTA_USER_SCOPE to replace a list
-- GET_QUOTA_SCOPE()
--     -> GET_QUOTA_SCOPE_V2()

-- ---------------------------------------------------------------------
-- Post-migration verification
-- ---------------------------------------------------------------------
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!GET_QUOTA_SCOPE_V2();
CALL PUQ_GOVERNANCE_DB.QUOTAS.PUQ_WH_STANDARD_QUOTA!GET_USERS();
-- Allow ~10-15 minutes after role/tag changes before comparing the
-- resolved population against the intended population.

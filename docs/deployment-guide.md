# Deployment Guide

## Naming Convention

All objects use the `PUQ_` prefix (Per-User Quota). See README.md for the full naming reference table.

## Prerequisites
- Snowflake account with Per-User Quotas enabled (Public Preview — Open)
- ACCOUNTADMIN role access
- Verified email addresses for notification recipients

## Deploy

Execute `scripts/deploy.sql` as ACCOUNTADMIN in Snowsight. This script:

1. Creates `PUQ_GOVERNANCE_DB` with 3 schemas (QUOTAS, TAGS, ACTIONS)
2. Creates `PUQ_TEST_WH` (XSMALL, auto-suspend 60s)
3. Creates `PUQ_QUOTA_ADMIN_ROLE` and `PUQ_TEST_USER_ROLE`
4. Creates `PUQ_DEMO_USER` (dedicated test user — NOT you)
5. Creates 3 tags with APPLYBUDGET grants
6. Tags `PUQ_DEMO_USER` as engineering/standard/data-science
7. Creates 2 stored procedures (disable + re-enable)
8. Creates 3 quotas (AI standard, AI high tier, WH standard)
9. Configures notifications, block enforcement, custom actions
10. Validates the deployment

## Post-Deploy Checklist

- [ ] `PUQ_GOVERNANCE_DB` created with QUOTAS, TAGS, ACTIONS schemas
- [ ] `PUQ_TEST_WH` created (XSMALL, suspended)
- [ ] `PUQ_QUOTA_ADMIN_ROLE` and `PUQ_TEST_USER_ROLE` created
- [ ] `PUQ_DEMO_USER` created (not disabled, tagged correctly)
- [ ] Tags: COST_CENTER=engineering, USAGE_TIER=standard, DEPARTMENT=data-science
- [ ] `PUQ_AI_STANDARD_QUOTA`: 100/month, 10/day, block ON, TIER_1H
- [ ] `PUQ_AI_HIGH_TIER_QUOTA`: 500/month, 50/day, block ON, TIER_1H
- [ ] `PUQ_WH_STANDARD_QUOTA`: 50/month, 5/day, custom action at 100%
- [ ] Notifications configured on all 3 quotas
- [ ] CONFIRM_CUSTOM_ACTIONS_ACCESS() succeeds on WH quota

## Validate

```sql
-- Quick check:
-- Execute scripts/smoke-test.sql

-- Full validation:
-- Execute scripts/validate.sql
```

## Update Limits

```sql
USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;
CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(200);        -- raise monthly
CALL PUQ_AI_STANDARD_QUOTA!SET_PER_USER_LIMIT(20, 'DAILY'); -- raise daily
```

## Escalate a User

```sql
-- Move from standard to high tier:
USE ROLE ACCOUNTADMIN;
ALTER USER PUQ_DEMO_USER SET TAG PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER = 'high';
-- Blocks clear within ~15 minutes. User governed by PUQ_AI_HIGH_TIER_QUOTA.
```

## Teardown

Execute `scripts/teardown.sql` as ACCOUNTADMIN to remove ALL PUQ objects.

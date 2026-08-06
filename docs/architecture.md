# Architecture

## Naming Convention (PUQ_ Prefix)

All objects use the **PUQ_** prefix (Per-User Quota) for:
- Easy discovery: `SHOW ... LIKE 'PUQ_%'`
- Clean audit trails in ACCOUNT_USAGE
- Zero collision with production objects
- Simple teardown: drop everything with PUQ_ prefix

## Key Concepts

- `SNOWFLAKE.CORE.QUOTA` is a first-class schema-level object
- Two independent pipelines: Block Enforcement (minutes, AI only) and Evaluation Task (~6h / TIER_1H)
- Warehouse and AI domains cannot be combined (different credit units)
- Tags provide dynamic user scoping (UNION or INTERSECTION mode)
- TAG_REFERENCES lags ~2 hours for scope resolution

## RBAC Model

```
ACCOUNTADMIN
├── PUQ_QUOTA_ADMIN_ROLE
│   ├── SNOWFLAKE.QUOTA_CREATOR (database role)
│   ├── CREATE SNOWFLAKE.CORE.QUOTA ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS
│   ├── APPLYBUDGET ON TAGs (COST_CENTER, USAGE_TIER, DEPARTMENT)
│   ├── CREATE PROCEDURE ON SCHEMA PUQ_GOVERNANCE_DB.ACTIONS
│   └── MANAGE GRANTS ON ACCOUNT (for custom actions that ALTER USER)
└── PUQ_TEST_USER_ROLE
    └── Basic USAGE on warehouse/database/schema
```

## Multi-Tier Architecture

```
PUQ_AI_STANDARD_QUOTA (100/mo, 10/day)
  Scope: cost_center=engineering ∩ usage_tier=standard
  Enforcement: Block (AI), TIER_1H refresh
        │
        │  Escalation: ALTER USER ... SET TAG USAGE_TIER = 'high'
        ▼
PUQ_AI_HIGH_TIER_QUOTA (500/mo, 50/day)
  Scope: cost_center=engineering ∩ usage_tier=high
  Enforcement: Block (AI), TIER_1H refresh

PUQ_WH_STANDARD_QUOTA (50/mo, 5/day)
  Scope: cost_center=engineering ∩ usage_tier=standard
  Enforcement: Custom action → DISABLE_USERS_BY_ID at 100%
  Cycle-start: REENABLE_QUOTA_USERS at month boundary
```

## Data Flow

1. User executes AI/warehouse request
2. Metering pipeline attributes usage to user (minutes)
3. Block enforcement evaluates limits (AI only, minutes)
4. Evaluation task aggregates spending (~6h / TIER_1H)
5. Thresholds trigger notifications and custom actions
6. Events logged to `snowflake.telemetry.events`
7. Block history in `snowflake.account_usage.quota_access_block_history`

## Object Dependencies

```
PUQ_GOVERNANCE_DB
├── QUOTAS schema
│   ├── PUQ_AI_STANDARD_QUOTA   → depends on TAGS, PUQ_DEMO_USER
│   ├── PUQ_AI_HIGH_TIER_QUOTA  → depends on TAGS, PUQ_DEMO_USER
│   └── PUQ_WH_STANDARD_QUOTA   → depends on TAGS, ACTIONS, PUQ_TEST_WH
├── TAGS schema
│   ├── COST_CENTER tag          → applied to PUQ_DEMO_USER
│   ├── USAGE_TIER tag           → applied to PUQ_DEMO_USER
│   └── DEPARTMENT tag           → applied to PUQ_DEMO_USER
└── ACTIONS schema
    ├── DISABLE_USERS_BY_ID()    → granted to APPLICATION SNOWFLAKE
    └── REENABLE_QUOTA_USERS()   → granted to APPLICATION SNOWFLAKE
```

## See Also
- `diagrams/architecture.mmd` — system architecture
- `diagrams/governance.mmd` — governance flow
- `diagrams/sequence.mmd` — sequence diagram
- `diagrams/lifecycle.mmd` — quota lifecycle states

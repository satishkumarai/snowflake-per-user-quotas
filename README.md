# Snowflake Per-User Quotas (PUQ) — Enterprise Reference Implementation

> **Status**: Public Preview (Open to all accounts)  
> **Last Updated**: August 2026  
> **Minimum Role**: ACCOUNTADMIN (for initial setup only)

## Overview

Production-grade reference implementation for **Snowflake Per-User Quotas (PUQ)**, covering AI cost governance, warehouse spend controls, RBAC, notifications, block enforcement, custom actions, monitoring, and operational runbooks.

Per-user quotas let you enforce spending limits at a per-user granularity, preventing individual users from generating unwanted costs across AI functions, Cortex Agents, Snowflake CoWork, Snowflake CoCo, and warehouses.

---

## Naming Convention

All objects in this repository use the **`PUQ_`** prefix (short for **P**er-**U**ser **Q**uota) to ensure:
- Easy identification of all project-related objects
- Simple cleanup via `SHOW ... LIKE 'PUQ_%'`
- No collision with existing production objects
- Clear ownership and auditability

### Object Naming Reference

| Object Type | Name | Meaning |
|-------------|------|---------|
| Database | `PUQ_GOVERNANCE_DB` | Per-User Quota Governance Database |
| Schema | `PUQ_GOVERNANCE_DB.QUOTAS` | Houses quota objects |
| Schema | `PUQ_GOVERNANCE_DB.TAGS` | Houses scoping tags |
| Schema | `PUQ_GOVERNANCE_DB.ACTIONS` | Houses stored procedures |
| Warehouse | `PUQ_TEST_WH` | Per-User Quota Test Warehouse |
| Role | `PUQ_QUOTA_ADMIN_ROLE` | Quota administration role |
| Role | `PUQ_TEST_USER_ROLE` | Operational role for test user |
| User | `PUQ_DEMO_USER` | Dedicated test user (never production) |
| Tag | `PUQ_GOVERNANCE_DB.TAGS.COST_CENTER` | Business cost center |
| Tag | `PUQ_GOVERNANCE_DB.TAGS.USAGE_TIER` | Spending tier (sandbox/standard/high/executive) |
| Tag | `PUQ_GOVERNANCE_DB.TAGS.DEPARTMENT` | Organizational department |
| Quota | `PUQ_AI_STANDARD_QUOTA` | AI domains, standard tier (100 credits/mo) |
| Quota | `PUQ_AI_HIGH_TIER_QUOTA` | AI domains, high tier (500 credits/mo) |
| Quota | `PUQ_WH_STANDARD_QUOTA` | Warehouse compute, standard tier (50 credits/mo) |
| Procedure | `DISABLE_USERS_BY_ID(VARCHAR)` | Custom action: disable users at 100% |
| Procedure | `REENABLE_QUOTA_USERS()` | Cycle-start: re-enable users monthly |

---

## Safety Notice

**This implementation creates isolated test resources only.**

- A dedicated test user (`PUQ_DEMO_USER`) is created for all testing
- A dedicated database (`PUQ_GOVERNANCE_DB`) isolates all objects
- A dedicated warehouse (`PUQ_TEST_WH`) is used for compute
- **No existing users, roles, or objects are modified**
- Complete cleanup scripts remove every created object

---

## Repository Structure

```
snowflake-per-user-quotas/
├── README.md                    # This file
├── LICENSE                      # Apache 2.0
├── CHANGELOG.md                 # Release history
├── CONTRIBUTING.md              # Contribution guidelines
├── SECURITY.md                  # Security policy
├── .gitignore                   # Git ignore rules
│
├── docs/
│   ├── article.md               # Premium Medium article
│   ├── architecture.md          # Architecture documentation
│   ├── deployment-guide.md      # Step-by-step deployment
│   ├── operations-runbook.md    # Operational procedures
│   ├── troubleshooting.md       # Common issues and fixes
│   └── rollback.md              # Rollback procedures
│
├── diagrams/
│   ├── architecture.mmd         # System architecture (Mermaid)
│   ├── governance.mmd           # Governance flow (Mermaid)
│   ├── sequence.mmd             # Sequence diagram (Mermaid)
│   └── lifecycle.mmd            # Quota lifecycle (Mermaid)
│
├── scripts/
│   ├── deploy.sql               # Full deployment script (631 lines)
│   ├── validate.sql             # Validation suite
│   ├── smoke-test.sql           # Quick validation
│   ├── rollback.sql             # Rollback (preserve environment)
│   └── teardown.sql             # Complete teardown
│
├── samples/
│   ├── sample-users.sql         # Escalation pattern examples
│   ├── sample-data.sql          # Spending data queries
│   └── sample-usage.sql         # Usage monitoring examples
│
└── tests/
    ├── test_01_environment.sql  # Database/schema/warehouse checks
    ├── test_02_users.sql        # Test user validation
    ├── test_03_tags.sql         # Tag assignment validation
    ├── test_04_quotas.sql       # Quota configuration checks
    ├── test_05_notifications.sql# Notification threshold checks
    ├── test_06_block_enforcement.sql
    ├── test_07_custom_actions.sql
    ├── test_08_monitoring.sql
    ├── test_09_reporting.sql
    └── test_10_cleanup.sql      # Cleanup verification
```

---

## Quick Start

```sql
-- 1. Deploy (run as ACCOUNTADMIN):
--    Execute scripts/deploy.sql (or the Untitled 3.sql worksheet)

-- 2. Validate:
--    Execute scripts/smoke-test.sql

-- 3. Run full test suite:
--    Execute scripts/validate.sql

-- 4. Tear down when finished:
--    Execute scripts/teardown.sql
```

---

## Multi-Tier Architecture

```
┌─────────────────────────────────────────────────┐
│  PUQ_AI_STANDARD_QUOTA (100 credits/mo)         │
│  Scope: cost_center=engineering + tier=standard  │
│  Block enforcement: ON                          │
├─────────────────────────────────────────────────┤
│  PUQ_AI_HIGH_TIER_QUOTA (500 credits/mo)        │
│  Scope: cost_center=engineering + tier=high      │
│  Block enforcement: ON                          │
├─────────────────────────────────────────────────┤
│  PUQ_WH_STANDARD_QUOTA (50 credits/mo)          │
│  Scope: cost_center=engineering + tier=standard  │
│  Custom action: disable user at 100%            │
└─────────────────────────────────────────────────┘

Escalation: ALTER USER PUQ_DEMO_USER SET TAG ...USAGE_TIER = 'high';
            → Moves user from standard to high tier automatically
            → Standard-tier blocks clear within ~15 minutes
```

---

## Supported Domains

| Domain | Monitored Costs | Block Enforcement | Unit |
|--------|----------------|-------------------|------|
| WAREHOUSE | Query execution compute | No | Credits |
| AI FUNCTION | AI Functions (COMPLETE, CLASSIFY, etc.) | Yes | AI Credits |
| SNOWFLAKE INTELLIGENCE | Snowflake CoWork operations | Yes | AI Credits |
| CORTEX AGENT | Cortex Agents operations | Yes | AI Credits |
| CORTEX CODE | Snowflake CoCo operations | Yes | AI Credits |

**Key constraint**: Warehouse and AI domains **cannot** be combined in the same quota (different unit types).

---

## Key Constraints

- Block enforcement applies **only** to AI domains, not warehouses
- Monthly cycle aligns to UTC calendar month (no custom cycles)
- All users in a quota share the same per-user limit (no per-user overrides)
- Evaluation for notifications/custom actions: ~6 hours (default) or <1 hour (TIER_1H)
- Block enforcement evaluates within **minutes** (separate pipeline)
- TAG_REFERENCES can lag ~2 hours (user scope resolution)
- Limit/scope changes propagate within ~15 minutes

---

## Prerequisites

- Snowflake account with Per-User Quotas enabled (Public Preview — Open)
- ACCOUNTADMIN role access for initial setup
- Verified email addresses for notification recipients

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

## Articles and architecture notes

- [Part 2: From Tag-Based Governance to Role-Based Control](docs/per-user-quota-part-2.md)

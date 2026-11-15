# Snowflake Per-User Quotas: From Tag-Based Governance to Role-Based Control

## How role-driven scope and individual credit-limit overrides change enterprise AI cost governance

Snowflake Per-User Quotas provide a way to govern consumption at the individual-user level. The November 11, 2026 GA enhancements add two important capabilities: role-based user scoping and individual quota limit overrides.

This is Part 2 of the Snowflake Per-User Quotas series.

Part 1: [Snowflake Per-User Quotas — Enterprise Reference Implementation](https://github.com/satishkumarai/snowflake-per-user-quotas)

## 1. What changed?

The original implementation used user tags to determine quota membership and applied a common limit to users within each quota.

The GA enhancements introduce:

- Role-based user scope.
- Include and exclude rules.
- UNION and INTERSECTION evaluation.
- Individual user quota overrides.
- Optional override expiration.
- Management procedures for inspecting and removing overrides.

Together, these capabilities separate population selection from individual policy exceptions.

## 2. Role-based user scoping

A quota can now target users through directly granted roles.

Example:

```sql
CALL my_quota!SET_QUOTA_USER_SCOPE(
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
```

`UNION` includes users matching any configured role or tag criterion. `INTERSECTION` requires users to match all configured criteria.

Role matching uses direct role grants. It does not automatically traverse inherited role hierarchies.

The scope model supports:

- `applies_to`: defines the target population.
- `excluded_by`: removes users based on roles or tags.
- `usernames`: explicitly includes or excludes named users.

Named-user rules are evaluated after the role and tag rules. An explicit inclusion can therefore include a user who was excluded by an earlier rule; an explicit exclusion keeps the user outside the scope.

## 3. Individual quota limit overrides

A common quota limit is useful for standard governance. It does not always fit every user.

For example, a developer testing an approved AI workload may need a temporary higher limit.

```sql
CALL my_quota!SET_USER_QUOTA_OVERRIDE(
  ['ALICE'],
  2500,
  'MONTHLY',
  '2026-12-01'
);
```

This sets Alice's monthly limit to 2,500 credits, with the override expiring at 00:00 UTC on December 1, 2026.

Supported cycles are `MONTHLY`, `WEEKLY`, and `DAILY`. Weekly and daily overrides apply to quotas scoped to AI domains.

Important operational details:

- The override replaces the default limit for that user and cycle.
- Up to 200 overrides can be stored per quota.
- Usernames are case-sensitive and must resolve to active account users.
- Expiration is optional.
- Existing overrides for the same user and cycle are updated.
- If multiple quotas apply, the lowest applicable limit still governs.
- Overrides do not change quota scope, monitored domains, or enforcement configuration.

## 4. Managing overrides

Use the supported procedures to inspect and remove exceptions:

```sql
CALL my_quota!LIST_USER_QUOTA_OVERRIDES();

CALL my_quota!REMOVE_USER_QUOTA_OVERRIDE(
  ['ALICE'],
  'MONTHLY'
);
```

Other removal procedures support removing overrides by user, by cycle, or removing all overrides.

Treat overrides as governed exceptions. Record the business reason, owner, approval, and expiry date in your operational process.

## 5. Architecture implications

A practical enterprise model now has four distinct layers:

1. Identity — users, roles, and tags.
2. Population — which users belong to a quota.
3. Default policy — the standard per-user limit.
4. Exceptions — approved user-specific overrides.

This separation makes quota policy easier to understand and operate.

## 6. Production considerations

A few details matter when designing the operating model:

- Role scope is based on direct grants, not inherited role hierarchy.
- Role and tag changes are not necessarily reflected immediately; validate effective membership after changes.
- Quota evaluation is not real-time. AI usage is generally reflected within minutes, while warehouse attribution can take longer.
- Overlapping quotas remain independently enforced.
- Overrides can remain stored while a user is outside the quota scope and become effective again if that user re-enters scope before expiry.
- Dropping and recreating a user with the same username does not transfer an override tied to the original internal user identity.
- AI and warehouse domains use different units and should not be combined in one quota.

## 7. Recommended adoption approach

For an existing tag-based implementation:

1. Inventory current quota objects and user tags.
2. Map the intended population to directly granted roles.
3. Define exclusions explicitly.
4. Validate effective membership before changing enforcement.
5. Introduce individual overrides only through an approval process.
6. Set expiry dates wherever possible.
7. Monitor spending and periodically review exceptions.

## Conclusion

Per-user quotas are more useful when enterprises can govern both the population and the exceptions.

Role-based scoping improves how users are selected. Individual overrides make it possible to accommodate legitimate differences without changing the default policy for everyone.

The important architectural shift is simple: define the population centrally, apply consistent defaults, and manage exceptions deliberately.

---

**Series:** Snowflake Per-User Quotas — Part 2  
**Implementation:** https://github.com/satishkumarai/snowflake-per-user-quotas  
**Author:** Snowflake Chronicles

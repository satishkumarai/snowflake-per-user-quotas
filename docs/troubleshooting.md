# Troubleshooting

## Quick Reference: PUQ Object Names

- Database: `PUQ_GOVERNANCE_DB`
- AI Quota: `PUQ_AI_STANDARD_QUOTA` / `PUQ_AI_HIGH_TIER_QUOTA`
- WH Quota: `PUQ_WH_STANDARD_QUOTA`
- Test User: `PUQ_DEMO_USER`
- Admin Role: `PUQ_QUOTA_ADMIN_ROLE`

---

## Common Issues

### "Insufficient privileges" creating quota
**Fix**:
```sql
GRANT DATABASE ROLE SNOWFLAKE.QUOTA_CREATOR TO ROLE PUQ_QUOTA_ADMIN_ROLE;
GRANT CREATE SNOWFLAKE.CORE.QUOTA ON SCHEMA PUQ_GOVERNANCE_DB.QUOTAS
    TO ROLE PUQ_QUOTA_ADMIN_ROLE;
```

### GET_USERS returns empty after tagging
**Cause**: TAG_REFERENCES lags ~2 hours. Wait and retry.

### Block enforcement not triggering
**Check**: Limit set? Block enabled (`GET_CONFIG`)? Domain enforceable (AI only)? User in scope?

### Custom action not firing
**Checklist**:
1. Procedure uses `EXECUTE AS OWNER`?
2. `GRANT USAGE ON PROCEDURE ... TO APPLICATION SNOWFLAKE` done?
3. `CALL PUQ_WH_STANDARD_QUOTA!CONFIRM_CUSTOM_ACTIONS_ACCESS()` returns success?
4. Threshold actually crossed?
5. Refresh tier latency? (default ~6h, TIER_1H <1h)

### Notifications not delivered
**Cause**: Email not verified, or sent-once-per-24h/cycle limit already hit.

### User briefly exceeds limit before block
**Expected**: Block evaluates within minutes, not at request time. Small overshoot is normal.

### Limit changes not taking effect
**Expected**: ~15 minute propagation delay.

### Cannot mix warehouse and AI domains
**Fix**: Use separate quotas (`PUQ_AI_*` for AI, `PUQ_WH_*` for warehouse).

### User stuck disabled after month reset
**Cause**: No cycle-start action configured.
**Fix**: `CALL PUQ_WH_STANDARD_QUOTA!SET_CYCLE_START_ACTION(...)` or manually:
```sql
ALTER USER PUQ_DEMO_USER SET DISABLED = FALSE;
```

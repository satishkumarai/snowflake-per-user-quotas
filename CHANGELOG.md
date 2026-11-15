# Changelog

## [1.0.0] - 2026-08-06

### Added
- Full Per-User Quotas reference implementation
- AI quota with block enforcement (100 credits/month, 10/day)
- Warehouse quota with custom actions (50 credits/month, 5/day)
- Tag-based user scoping (INTERSECTION mode)
- Notification thresholds (PROJECTED and ACTUAL)
- Custom action: disable users at 100% actual spend
- Cycle-start reset action: re-enable users monthly
- Deployment, validation, rollback, and teardown scripts
- Mermaid diagrams (architecture, governance, sequence, lifecycle)
- Operations runbook and troubleshooting guide

## 2026-11-15

### Documentation
- Added Part 2 covering role-based quota scope and individual user quota overrides.
- Documented GA-era operational considerations and migration guidance.

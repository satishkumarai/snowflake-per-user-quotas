# Security Policy

- All test objects are isolated in QUOTA_TEST_DB
- Dedicated test user (QUOTA_TEST_USER) only
- No existing users modified
- Complete cleanup via teardown.sql
- Never commit real credentials

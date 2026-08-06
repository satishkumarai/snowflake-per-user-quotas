-- PUQ Test 09: Verify reporting/event table queries
USE ROLE ACCOUNTADMIN;

SELECT COUNT(*) AS PUQ_QUOTA_EVENTS
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP());
-- Expected: 0 or more

SELECT COUNT(*) AS PUQ_BLOCK_HISTORY
FROM snowflake.account_usage.quota_access_block_history
WHERE CREATED_ON > DATEADD('day', -30, CURRENT_TIMESTAMP());
-- Expected: 0 or more

-- PUQ 06b: Admin Summary Notifications and Notification Integrations
-- =============================================================================
-- Demonstrates all documented notification methods:
--   ADD_NOTIFICATION_THRESHOLD  — individual user notifications
--   SET_ADMIN_EMAILS            — admin summary via email
--   ADD_NOTIFICATION_INTEGRATION — admin summary via integration
--   GET_NOTIFICATION_THRESHOLDS — list configured thresholds
--   GET_NOTIFICATION_INTEGRATIONS — list configured integrations
--   REMOVE_NOTIFICATION_THRESHOLD — remove a threshold
--   REMOVE_NOTIFICATION_INTEGRATION — remove an integration
--
-- Per docs:
--   - Projected: sent at most once per threshold per user within 24 hours
--   - Actual: sent at most once per user per quota cycle
--   - Email addresses must be verified for delivery
--   - Admin summary sent after evaluation when new breaches detected
--
-- ROLE REQUIRED: PUQ_QUOTA_ADMIN_ROLE
-- =============================================================================

USE ROLE PUQ_QUOTA_ADMIN_ROLE;
USE SCHEMA PUQ_GOVERNANCE_DB.QUOTAS;

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDIVIDUAL USER NOTIFICATIONS (user gets email at threshold)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Already configured in 06-notifications/setup_notifications.sql:
--   50% PROJECTED, 80% PROJECTED, 90% ACTUAL, 100% ACTUAL

-- Example: Add a new threshold at 70% projected (not notifying user).
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_THRESHOLD(70, 'PROJECTED', FALSE);

-- Example: Remove a threshold.
-- CALL PUQ_AI_STANDARD_QUOTA!REMOVE_NOTIFICATION_THRESHOLD(70, 'PROJECTED');

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADMIN SUMMARY NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Via email (already configured).
-- CALL PUQ_AI_STANDARD_QUOTA!SET_ADMIN_EMAILS('admin1@example.com, admin2@example.com');

-- Via notification integration (if configured in your account).
-- CALL PUQ_AI_STANDARD_QUOTA!ADD_NOTIFICATION_INTEGRATION('my_notification_integration');

-- View configured integrations.
CALL PUQ_AI_STANDARD_QUOTA!GET_NOTIFICATION_INTEGRATIONS();

-- Remove an integration.
-- CALL PUQ_AI_STANDARD_QUOTA!REMOVE_NOTIFICATION_INTEGRATION('my_notification_integration');

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════════

-- List all configured notification thresholds.
CALL PUQ_AI_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();
CALL PUQ_AI_HIGH_TIER_QUOTA!GET_NOTIFICATION_THRESHOLDS();
CALL PUQ_WH_STANDARD_QUOTA!GET_NOTIFICATION_THRESHOLDS();

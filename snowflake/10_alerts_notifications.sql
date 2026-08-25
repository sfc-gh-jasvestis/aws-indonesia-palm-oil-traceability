-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_indonesia_palm_oil_traceability_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: TRACEABILITY_GAP_ALERT
CREATE OR REPLACE ALERT APP.TRACEABILITY_GAP_ALERT
  WAREHOUSE = TRACEABILITY_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Mill traceability below 95% threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.FULL_CHAIN_OF_CUSTODY
  WHERE 1=1 -- Condition: TRACEABILITY_PCT < 95 for any mill
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_palm_oil_traceability_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Supply Chain Traceability: Mill traceability below 95% threshold',
    'Mill traceability below 95% threshold'
  );

ALTER ALERT APP.TRACEABILITY_GAP_ALERT RESUME;

-- Alert: MASS_BALANCE_ALERT
CREATE OR REPLACE ALERT APP.MASS_BALANCE_ALERT
  WAREHOUSE = TRACEABILITY_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Mass balance variance exceeds 5% tolerance'
IF (EXISTS (
  SELECT 1 FROM CURATED.FULL_CHAIN_OF_CUSTODY
  WHERE 1=1 -- Condition: VARIANCE_PCT > 5 for any mill-month
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_palm_oil_traceability_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Supply Chain Traceability: Mass balance variance exceeds 5% tolerance',
    'Mass balance variance exceeds 5% tolerance'
  );

ALTER ALERT APP.MASS_BALANCE_ALERT RESUME;


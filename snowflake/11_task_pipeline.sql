-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CHAIN
  WAREHOUSE = TRACEABILITY_WH
  SCHEDULE = 'USING CRON 0 */2 * * * UTC'
  COMMENT = 'Refresh chain-of-custody Dynamic Tables'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_RECONCILE_MASS_BALANCE
  WAREHOUSE = TRACEABILITY_WH
  AFTER APP.TASK_REFRESH_CHAIN
  COMMENT = 'Run mass balance reconciliation'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_REFRESH_ICEBERG
  WAREHOUSE = TRACEABILITY_WH
  AFTER APP.TASK_RECONCILE_MASS_BALANCE
  COMMENT = 'Refresh Iceberg tables for auditor Athena access'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_REFRESH_ICEBERG RESUME;
ALTER TASK APP.TASK_RECONCILE_MASS_BALANCE RESUME;
ALTER TASK APP.TASK_REFRESH_CHAIN RESUME;

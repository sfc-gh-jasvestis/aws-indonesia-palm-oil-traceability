-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.AUDIT_REPORT_SEARCH
  ON CONTENT
  ATTRIBUTES MILL_ID, AUDIT_TYPE, FINDING_SEVERITY
  WAREHOUSE = TRACEABILITY_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.AUDIT_REPORTS
);

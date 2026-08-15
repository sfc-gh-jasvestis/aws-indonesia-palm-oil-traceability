-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.TRACEABILITY_ANALYTICS
  COMMENT = 'Supply chain traceability, chain-of-custody, and audit analytics for Indonesian palm oil'
AS
  TABLES (
    CURATED.FULL_CHAIN_OF_CUSTODY AS full_chain_of_custody,CURATED.MILL_TRACEABILITY_SCORE AS mill_traceability_score,CURATED.BUYER_SUPPLY_CHAIN_VIEW AS buyer_supply_chain_view,CURATED.MASS_BALANCE_RECONCILIATION AS mass_balance_reconciliation
  );

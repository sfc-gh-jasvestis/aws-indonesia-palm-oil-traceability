-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.TRACEABILITY_AGENT
  COMMENT = 'Supply Chain Traceability AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'PALM_OIL_TRACEABILITY_ID.APP.TRACEABILITY_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'PALM_OIL_TRACEABILITY_ID.SEARCH.AUDIT_REPORT_SEARCH', TOOL_DESCRIPTION => 'Search documents for Palm Oil & Agriculture information')
  )
  SYSTEM_PROMPT = 'You are the Supply Chain Traceability Agent for Indonesia''s largest palm oil group with 300 mills and 5,000 smallholder suppliers across Sumatra and Kalimantan.';

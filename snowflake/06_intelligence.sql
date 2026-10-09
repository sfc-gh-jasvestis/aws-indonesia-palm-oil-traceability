-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live custody-transfer alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TRANSFERS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic chain-of-custody SOPs (clearly synthetic, not audit guidance) ----------
CREATE OR REPLACE TABLE SEARCH.CUSTODY_SOP_DOCS AS
WITH signals AS (
  SELECT DISTINCT r.RISK_SIGNAL, m.CATEGORY
  FROM RAW.MILL_DAILY r JOIN RAW.MILLS m ON m.ID = r.ENTITY_ID
  WHERE r.CONFIRMED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, RISK_SIGNAL)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  RISK_SIGNAL,
  CATEGORY || ' - ' || RISK_SIGNAL || ' follow-up' AS TITLE,
  'Synthetic demo SOP for a fictional CPO supply chain; not audit or certification guidance. Sourcing model: ' || CATEGORY || '. Custody signal: ' || RISK_SIGNAL || '. '
  || 'Step 1: hold the affected CPO lots at the receiving refinery tank, and notify the mill traceability officer within 1 business day. '
  || 'Step 2: ' || CASE
       WHEN RISK_SIGNAL = 'Tank stock variance' THEN 'compare the mill storage tank dip readings with the dispatch log for the same day, and recount the closing stock with the mill manager.'
       WHEN RISK_SIGNAL = 'Seal number mismatch' THEN 'match the tank truck seal numbers on the delivery order with the seals recorded at refinery intake, and photograph any broken or replaced seal.'
       WHEN RISK_SIGNAL = 'Delivery order missing' THEN 'request the signed delivery order from the plasma scheme mill, and keep the lot on hold until the order number matches the weighbridge ticket.'
       WHEN RISK_SIGNAL = 'Unregistered supplier intake' THEN 'identify the FFB suppliers behind the intake batch, and register each supplier with a plantation link or reject the batch from the traceable stock.'
       WHEN RISK_SIGNAL = 'Weighbridge ticket gap' THEN 'reconcile the weighbridge ticket sequence for the day, and ask the mill to explain every missing ticket number.'
       WHEN RISK_SIGNAL = 'Mass balance variance' THEN 'recompute the mill mass balance from FFB intake, extraction rate and CPO dispatched, and ask the mill to explain any gap above tolerance.'
       WHEN RISK_SIGNAL = 'Dealer source list incomplete' THEN 'request the full source list from the FFB dealer, and keep the dealer share of the lot out of traceable stock until the list is complete.'
       WHEN RISK_SIGNAL = 'Tank transfer unrecorded' THEN 'ask the toll-processing mill for the tank transfer record and the toll customer contract, and match both to the dispatched volume.'
       ELSE 'review the transfer against the dispatch log and escalate if unexplained.'
     END
  || ' Step 3: if the mass-balance variance exceeds 5% or more than a third of the CPO tonnes cannot be traced to a plantation, keep the case open and schedule a mill visit. '
  || 'Step 4: record the outcome and the evidence; release the lot to traceable stock only with sign-off from the traceability lead.' AS CONTENT
FROM signals;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.CUSTODY_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, RISK_SIGNAL
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, RISK_SIGNAL, CONTENT FROM SEARCH.CUSTODY_SOP_DOCS);

-- ---------- Mass-balance variance anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.MB_VARIANCE_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, MB_VARIANCE_PCT::FLOAT AS MB_VARIANCE
FROM RAW.MILL_DAILY;
CREATE OR REPLACE VIEW ML.MB_VARIANCE_TRAIN AS
SELECT * FROM ML.MB_VARIANCE_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.MB_VARIANCE_SERIES);
CREATE OR REPLACE VIEW ML.MB_VARIANCE_DETECT AS
SELECT * FROM ML.MB_VARIANCE_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.MB_VARIANCE_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.MB_VARIANCE_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.MB_VARIANCE_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'MB_VARIANCE',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.MB_VARIANCE_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS MB_VARIANCE, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.MB_VARIANCE_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.MB_VARIANCE_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'MB_VARIANCE'));


-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.TRACEABILITY_ANALYTICS
  TABLES (
    mills AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'mills', 'palm oil mills')
      COMMENT = 'One row per mill (city x sourcing model), 90-day totals',
    risk AS ML.CUSTODY_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day probability of a confirmed custody break per mill',
    signals AS CURATED.SIGNAL_SUMMARY PRIMARY KEY (RISK_SIGNAL)
      COMMENT = 'Custody flags, confirmed custody breaks and held lots by custody signal, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_mill AS risk (ENTITY_ID) REFERENCES mills)
  FACTS (
    mills.dispatches_f AS DISPATCH_COUNT,
    mills.traced_f AS TRACED_TONNES,
    mills.cpo_f AS CPO_TONNES,
    mills.flags_f AS FLAG_COUNT,
    mills.confirmed_f AS CONFIRMED_COUNT,
    mills.held_f AS HELD_COUNT,
    mills.recon_due_f AS RECONCILIATION_DUE,
    mills.recon_received_f AS RECONCILIATION_RECEIVED,
    risk.break_prob_f AS BREAK_PROB_7D,
    signals.sig_flags_f AS FLAG_COUNT,
    signals.sig_confirmed_f AS CONFIRMED_COUNT,
    signals.sig_held_f AS HELD_COUNT,
    daily.day_dispatches_f AS DISPATCH_COUNT,
    daily.day_traced_f AS TRACED_TONNES,
    daily.day_cpo_f AS CPO_TONNES,
    daily.day_flags_f AS FLAG_COUNT
  )
  DIMENSIONS (
    mills.mill_id AS ENTITY_ID WITH SYNONYMS = ('entity', 'mill', 'mill id'),
    mills.mill_name AS ENTITY_NAME,
    mills.city AS REGION WITH SYNONYMS = ('city', 'region', 'mill hub') COMMENT = 'Indonesian city of the mill',
    mills.sourcing_model AS CATEGORY WITH SYNONYMS = ('sourcing model', 'mill type', 'category'),
    mills.risk_tier AS RISK_TIER COMMENT = 'Sourcing risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    signals.risk_signal AS RISK_SIGNAL WITH SYNONYMS = ('signal', 'custody signal', 'red flag'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    mills.mill_count AS COUNT(mills.mill_id) WITH SYNONYMS = ('number of entities', 'number of mills'),
    mills.traceability_to_plantation_pct AS 100 * SUM(mills.traced_f) / NULLIF(SUM(mills.cpo_f), 0)
      COMMENT = 'CPO tonnes traceable to a plantation / CPO tonnes dispatched',
    mills.total_dispatches AS SUM(mills.dispatches_f) WITH SYNONYMS = ('custody transfers', 'CPO dispatches'),
    mills.total_traced_tonnes AS SUM(mills.traced_f) WITH SYNONYMS = ('traced tonnes', 'tonnes traced to plantation'),
    mills.total_cpo_tonnes AS SUM(mills.cpo_f) WITH SYNONYMS = ('CPO dispatched', 'CPO tonnes'),
    mills.total_flags AS SUM(mills.flags_f) WITH SYNONYMS = ('custody flags', 'flags'),
    mills.total_confirmed AS SUM(mills.confirmed_f) WITH SYNONYMS = ('confirmed custody breaks', 'confirmed breaks'),
    mills.total_held AS SUM(mills.held_f) WITH SYNONYMS = ('held lots', 'lots held'),
    mills.flag_precision_pct AS 100 * SUM(mills.confirmed_f) / NULLIF(SUM(mills.flags_f), 0)
      COMMENT = 'Confirmed custody breaks / custody flags',
    mills.reconciliation_rate_pct AS 100 * SUM(mills.recon_received_f) / NULLIF(SUM(mills.recon_due_f), 0)
      COMMENT = 'Mass-balance reconciliations received / reconciliations due',
    risk.avg_break_prob AS AVG(risk.break_prob_f),
    signals.signal_flags AS SUM(signals.sig_flags_f),
    signals.signal_confirmed AS SUM(signals.sig_confirmed_f),
    signals.signal_held AS SUM(signals.sig_held_f),
    signals.signal_precision_pct AS 100 * SUM(signals.sig_confirmed_f) / NULLIF(SUM(signals.sig_flags_f), 0),
    daily.daily_dispatches AS SUM(daily.day_dispatches_f),
    daily.daily_cpo_tonnes AS SUM(daily.day_cpo_f),
    daily.daily_traceability_pct AS 100 * SUM(daily.day_traced_f) / NULLIF(SUM(daily.day_cpo_f), 0),
    daily.daily_flags AS SUM(daily.day_flags_f)
  )
  COMMENT = 'Synthetic Indonesia palm oil mill-to-refinery traceability analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.TRACEABILITY_AGENT
  COMMENT = 'Mill-to-refinery chain-of-custody assistant over a synthetic palm oil supply chain'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic and that custody checks are demo signals, not audit or certification verdicts. Give mill IDs and numbers with units."
  orchestration: "Use custody_analyst for CPO custody transfers, CPO dispatched and traced tonnes, traceability to plantation, custody flags, confirmed custody breaks, held lots, mass-balance reconciliations, cities, sourcing models, custody signals and custody-break risk. Use sop_search for follow-up procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: custody_analyst
      description: "CPO custody transfers, CPO tonnes, traceability to plantation, custody flags, confirmed custody breaks, held lots, flag precision, mass-balance reconciliation rate, custody signals and custody-break risk scores by mill"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic chain-of-custody follow-up SOPs by sourcing model and custody signal"
tool_resources:
  custody_analyst:
    semantic_view: __DEMO_DB__.APP.TRACEABILITY_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.CUSTODY_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live custody-transfer alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), MILL_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, TRANSFER_TONNES FLOAT, MB_VARIANCE_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION ID_PALM_OIL_TRACEABILITY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_FLAGS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (MILL_ID, EVENT_TS, TRANSFER_TONNES, MB_VARIANCE_PCT, SOP_HINT)
    SELECT c.MILL_ID, c.EVENT_TS, c.TRANSFER_TONNES, c.MB_VARIANCE_PCT,
           'Check ' || m.CATEGORY || ' custody SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TRANSFERS c
    JOIN RAW.MILLS m ON m.ID = c.MILL_ID
    LEFT JOIN ML.CUSTODY_RISK_SCORES r ON r.ENTITY_ID = c.MILL_ID
    WHERE c.STATUS = 'FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.MILL_ID = c.MILL_ID AND l.EVENT_TS = c.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('ID_PALM_OIL_TRACEABILITY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] CPO custody-transfer alert',
      'New flagged live custody transfers logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_TRANSFER_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TRANSFERS c
    WHERE c.STATUS = 'FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.MILL_ID = c.MILL_ID AND l.EVENT_TS = c.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_FLAGS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.SIGNAL_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.CUSTODY_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.CUSTODY_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.CUSTODY_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'PROGRAM_YEARS', PROGRAM_YEARS,
             'MB_VARIANCE_PCT', MB_VARIANCE_PCT, 'UNTRACED_PCT', UNTRACED_PCT,
             'MB_VARIANCE_7D', MB_VARIANCE_7D, 'CONFIRMED_30D', CONFIRMED_30D,
           'DAYS_SINCE_RECON', DAYS_SINCE_RECON, 'RECON_RATE_30D', RECON_RATE_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:BREAK::FLOAT, 4) AS BREAK_PROB_7D,
         CASE WHEN PRED:probability:BREAK::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:BREAK::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;

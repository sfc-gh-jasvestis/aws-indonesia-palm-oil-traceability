-- Synthetic mill observations for a fictional palm oil crude palm oil (CPO)
-- supply chain in Indonesia. 40 mills = 8 cities x 5 sourcing models. Nothing
-- is seeded as a prediction. Randomness is HASH-seeded, so every rebuild is
-- reproducible: per-mill custody-break propensity, drift between periodic
-- mass-balance reconciliations, missed reconciliations, model-weighted custody
-- signals, false-positive custody flags, and two area-wide weighbridge system
-- outages. Custody checks are demo signals, not audit or certification verdicts.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.MILLS AS
WITH mills AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS MILL_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT MILL_INDEX,
         MOD(ABS(HASH(MILL_INDEX, 'program')), 1000000) / 1e6 AS U_PROGRAM,
         MOD(ABS(HASH(MILL_INDEX, 'rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(MILL_INDEX, 'reconcile')), 1000000) / 1e6 AS U_RECONCILE,
         MOD(ABS(HASH(MILL_INDEX, 'discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(MILL_INDEX, 'tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(MILL_INDEX, 'size')), 1000000) / 1e6 AS U_SIZE
  FROM mills
), mills_named AS (
  SELECT *,
         -- Every city x sourcing model combination appears exactly once.
         CASE MOD(MILL_INDEX, 8) WHEN 0 THEN 'Pekanbaru' WHEN 1 THEN 'Medan'
              WHEN 2 THEN 'Jambi' WHEN 3 THEN 'Palembang' WHEN 4 THEN 'Bengkulu'
              WHEN 5 THEN 'Pontianak' WHEN 6 THEN 'Sampit'
              ELSE 'Samarinda' END AS REGION,
         CASE FLOOR(MILL_INDEX / 8) WHEN 0 THEN 'Integrated estate mill'
              WHEN 1 THEN 'Plasma scheme mill' WHEN 2 THEN 'Smallholder-sourced mill'
              WHEN 3 THEN 'Dealer-supplied mill' ELSE 'Toll-processing mill' END AS CATEGORY
  FROM draws
)
SELECT 'MILL-' || LPAD(MILL_INDEX::VARCHAR, 4, '0') AS ID,
       REGION || ' ' || CATEGORY AS NAME,
       REGION, CATEGORY, MILL_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.3 + U_PROGRAM * 5.7, 1) AS PROGRAM_YEARS,
       ROUND(0.6 + U_SIZE * 0.8, 3) AS SIZE_FACTOR,
       -- Base daily probability of a confirmed custody break 0.3%-2.5%, higher
       -- where sourcing is indirect; ~15% of mills are weak links (x3).
       (0.003 + U_RATE * 0.022)
         * CASE CATEGORY WHEN 'Integrated estate mill' THEN 0.4 WHEN 'Plasma scheme mill' THEN 0.8
                         WHEN 'Smallholder-sourced mill' THEN 1.3 WHEN 'Dealer-supplied mill' THEN 1.6
                         ELSE 1.2 END
         * IFF(U_RATE > 0.85, 3, 1) AS BASE_BREAK_RATE,
       7 * (1 + FLOOR(U_RECONCILE * 3)) AS RECONCILIATION_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS RECONCILIATION_RETURN_PROB,
       -- Share of CPO tonnes that typically cannot be traced back to a plantation.
       CASE CATEGORY WHEN 'Integrated estate mill' THEN 2 WHEN 'Plasma scheme mill' THEN 8
                     WHEN 'Smallholder-sourced mill' THEN 26 WHEN 'Dealer-supplied mill' THEN 35
                     ELSE 18 END AS BASE_UNTRACED_PCT,
       'Active' AS STATUS
FROM mills_named;

CREATE TABLE RAW.MILL_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), outage_events AS (
  -- Two area-wide weighbridge system outages; every mill in the city gets a flag.
  SELECT * FROM VALUES (27, 'Pekanbaru'), (64, 'Sampit') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT m.ID AS ENTITY_ID, m.MILL_INDEX, m.CATEGORY, m.REGION, m.PROGRAM_YEARS,
         m.SIZE_FACTOR, m.BASE_UNTRACED_PCT,
         m.BASE_BREAK_RATE, m.RECONCILIATION_INTERVAL_DAYS, m.RECONCILIATION_RETURN_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + m.MILL_INDEX * 5, m.RECONCILIATION_INTERVAL_DAYS) AS DAYS_SINCE_RECONCILIATION,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'break')), 1000000) / 1e6 AS U_BREAK,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'fp')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'signal')), 1000000) / 1e6 AS U_SIG,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'trucks')), 1000000) / 1e6 AS U_TRUCKS,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(m.ID, d.DAY_INDEX, 'hold')), 1000000) / 1e6 AS U_HOLD,
         o.REGION IS NOT NULL AS OUTAGE_EVENT
  FROM RAW.MILLS m CROSS JOIN days d
  LEFT JOIN outage_events o ON o.DAY_INDEX = d.DAY_INDEX AND o.REGION = m.REGION
), reconciliations AS (
  SELECT *,
         IFF(DAYS_SINCE_RECONCILIATION = 0, 1, 0) AS RECONCILIATION_DUE,
         IFF(DAYS_SINCE_RECONCILIATION = 0 AND U_DONE < RECONCILIATION_RETURN_PROB, 1, 0) AS RECONCILIATION_RECEIVED,
         -- Custody drift rises between mass-balance reconciliations; weak discipline carries it over.
         DAYS_SINCE_RECONCILIATION / RECONCILIATION_INTERVAL_DAYS + (1 - RECONCILIATION_RETURN_PROB) AS DRIFT
  FROM base
), activity AS (
  SELECT *,
         CASE WHEN U_BREAK < LEAST(0.5, BASE_BREAK_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAM_YEARS))) / 4 THEN 2
              WHEN U_BREAK < LEAST(0.5, BASE_BREAK_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAM_YEARS))) THEN 1
              ELSE 0 END AS BREAK_COUNT
  FROM reconciliations
), checks AS (
  SELECT *,
         -- Custody checks catch about 85% of breaks; the rest stays undetected.
         IFF(OUTAGE_EVENT, 0, IFF(U_DETECT < 0.85, BREAK_COUNT, 0)) AS CONFIRMED_COUNT,
         -- False-positive flags: higher where sourcing records are weaker.
         IFF(OUTAGE_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Smallholder-sourced mill' THEN 0.16
                                                       WHEN 'Dealer-supplied mill' THEN 0.15
                                                       WHEN 'Toll-processing mill' THEN 0.13
                                                       WHEN 'Plasma scheme mill' THEN 0.10 ELSE 0.07 END, 1, 0)) AS FALSE_POSITIVE_COUNT
  FROM activity
), measured AS (
  SELECT *,
         CONFIRMED_COUNT + FALSE_POSITIVE_COUNT AS FLAG_COUNT,
         ROUND(CASE CATEGORY WHEN 'Integrated estate mill' THEN 18 WHEN 'Plasma scheme mill' THEN 14
                             WHEN 'Smallholder-sourced mill' THEN 10 WHEN 'Dealer-supplied mill' THEN 12 ELSE 8 END
               * SIZE_FACTOR * (0.7 + 0.6 * U_TRUCKS)) AS DISPATCH_COUNT,
         -- CPO tank trucks carry roughly 20-32 tonnes per custody transfer.
         CASE CATEGORY WHEN 'Integrated estate mill' THEN 30 WHEN 'Plasma scheme mill' THEN 28
                       WHEN 'Smallholder-sourced mill' THEN 24 WHEN 'Dealer-supplied mill' THEN 25 ELSE 22 END
           * (0.9 + 0.2 * U_NOISE) AS AVG_DISPATCH_TONNES,
         LEAST(95, BASE_UNTRACED_PCT + 6 * DRIFT + 8 * BREAK_COUNT + 2 * U_NOISE) AS UNTRACED_SHARE
  FROM checks
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       DISPATCH_COUNT,
       ROUND(DISPATCH_COUNT * AVG_DISPATCH_TONNES * (1 - UNTRACED_SHARE / 100), 2) AS TRACED_TONNES,
       ROUND(DISPATCH_COUNT * AVG_DISPATCH_TONNES, 2) AS CPO_TONNES,
       FLAG_COUNT, CONFIRMED_COUNT,
       IFF(CONFIRMED_COUNT > 0 AND U_HOLD < 0.6, 1, 0) AS LOTS_HELD,
       CASE WHEN FLAG_COUNT = 0 THEN 'None'
            WHEN OUTAGE_EVENT THEN 'Weighbridge system outage'
            WHEN CATEGORY = 'Integrated estate mill' THEN IFF(U_SIG < 0.6, 'Tank stock variance', 'Seal number mismatch')
            WHEN CATEGORY = 'Plasma scheme mill' THEN IFF(U_SIG < 0.55, 'Seal number mismatch', 'Delivery order missing')
            WHEN CATEGORY = 'Smallholder-sourced mill' THEN IFF(U_SIG < 0.45, 'Unregistered supplier intake', IFF(U_SIG < 0.8, 'Weighbridge ticket gap', 'Mass balance variance'))
            WHEN CATEGORY = 'Dealer-supplied mill' THEN IFF(U_SIG < 0.55, 'Dealer source list incomplete', 'Unregistered supplier intake')
            ELSE IFF(U_SIG < 0.5, 'Tank transfer unrecorded', 'Mass balance variance') END AS RISK_SIGNAL,
       RECONCILIATION_DUE, RECONCILIATION_RECEIVED,
       ROUND(0.5 + 2.0 * DRIFT + 3.0 * BREAK_COUNT + U_NOISE * 0.8, 2) AS MB_VARIANCE_PCT,
       ROUND(UNTRACED_SHARE, 1) AS UNTRACED_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- FFB supplier registry per mill (snapshot): registered suppliers, suppliers
-- with a verified plantation link on file, and verifications still pending.
CREATE TABLE RAW.SUPPLIER_REGISTRY AS
WITH sized AS (
  SELECT ID, CATEGORY,
         ROUND(CASE CATEGORY WHEN 'Integrated estate mill' THEN 25 WHEN 'Plasma scheme mill' THEN 320
                             WHEN 'Smallholder-sourced mill' THEN 900 WHEN 'Dealer-supplied mill' THEN 480 ELSE 160 END
               * (0.6 + MOD(ABS(HASH(ID, 'suppliers')), 1000000) / 1e6 * 0.8)) AS SUPPLIERS,
         CASE CATEGORY WHEN 'Integrated estate mill' THEN 1.0 WHEN 'Plasma scheme mill' THEN 0.86
                       WHEN 'Smallholder-sourced mill' THEN 0.55 WHEN 'Dealer-supplied mill' THEN 0.42 ELSE 0.6 END
           + MOD(ABS(HASH(ID, 'linked')), 1000000) / 1e6 * 0.25 AS LINK_SHARE
  FROM RAW.MILLS
)
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Integrated estate mill' THEN 'Estate division records'
                     WHEN 'Plasma scheme mill' THEN 'Plasma cooperative member list'
                     WHEN 'Smallholder-sourced mill' THEN 'Smallholder supplier register'
                     WHEN 'Dealer-supplied mill' THEN 'Dealer-declared source list'
                     ELSE 'Toll customer source list' END AS EVIDENCE_TYPE,
       SUPPLIERS AS REQUIRED_QTY,
       LEAST(SUPPLIERS, ROUND(SUPPLIERS * LINK_SHARE)) AS ON_FILE_QTY,
       ROUND((SUPPLIERS - LEAST(SUPPLIERS, ROUND(SUPPLIERS * LINK_SHARE))) * MOD(ABS(HASH(ID, 'pending')), 1000000) / 1e6 * 0.6) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM sized;

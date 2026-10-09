# Palm Oil Mill-to-Refinery Traceability

**Indonesia - Agriculture supply chain**
Use case: Chain of custody for crude palm oil (CPO) from mill to refinery in a fictional supply chain

> Chain-of-custody analytics for 40 palm oil mills in a fictional CPO supply chain across 8 Indonesian cities and 5 sourcing models: dynamic tables, a holdout-evaluated custody-break classifier, a CPO custody-transfer forecast and grounded AI answers. Custody checks are demo signals, not audit or certification verdicts.

## Why Snowflake

- **Dynamic tables** reconcile CPO custody transfers, traceability to plantation, custody flags, confirmed custody breaks and mass-balance reconciliation rates from RAW mill data, with checks in `run_core.py`
- **Custody-break classification** gives a holdout-evaluated next-7-day probability per mill
- **Dispatch forecast** projects 14 days of network-wide CPO custody transfers with prediction intervals, for refinery intake planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live transfers**: a native dispatch simulator (Snowflake only) or Amazon Data Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.MILLS` (40 rows) |
| Fact table | `RAW.MILL_DAILY` (3,600 mill-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `SIGNAL_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.CUSTODY_RISK_SCORES`, `ML.CUSTODY_RISK_HOLDOUT_METRICS`, `ML.DISPATCH_FORECAST`, `ML.MB_VARIANCE_ANOMALIES` |

Cities: Pekanbaru, Medan, Jambi, Palembang, Bengkulu, Pontianak, Sampit, Samarinda.
Sourcing models: Integrated estate mill, Plasma scheme mill, Smallholder-sourced mill, Dealer-supplied mill, Toll-processing mill.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Traceability to Plantation | 79.8% |
| CPO Custody Transfers | 48,712 |
| CPO Dispatched (kt) | 1,290 |
| Custody Flags | 569 |
| Confirmed Custody Breaks | 124 |
| Flag Precision | 21.8% |
| Lots Held at Refinery | 61 |
| Mass-Balance Reconciliation Rate | 78.4% |
| Mills Monitored | 40 |
| Supplier Link Coverage | 69.0% |
| Supplier Verifications Pending | 1,030 |
| Registered FFB Suppliers | 15,522 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily CPO custody transfers against custody flags, flags and confirmed custody breaks by custody signal, mill table
2. Predictive: holdout metrics, risk bands, 14-day CPO dispatch forecast, mass-balance variance anomalies
3. Supplier Registry: mass-balance reconciliation rate, supplier link coverage and pending verifications, reconciliation rate against confirmed breaks, then generate the action memo
4. Live Transfers: run `CALL APP.SIMULATE_TRANSFERS(20)` (Snowflake only) or `python aws/publish_transfers.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_TRANSFER_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About one custody flag in five is confirmed as a custody break (21.8%). Most flags end as false positives, which is where the traceability team's time goes.
- Mass balance variance produces the most confirmed breaks; unregistered supplier intake raises the most flags (124) but only 15 are confirmed. Weighbridge system outage flags hit every mill in a city at once and are never confirmed.
- The risk model is evaluated on a time-based holdout: precision 0.26 and recall 0.23 at 0.5, against a 0.15 base rate. Present it as triage, not a verdict. Forecast and anomaly figures can shift slightly with the build day.
- Weighbridge system outage days are excluded from model training, because they are not driven by the mill.

## Business impact

Use only the sourced references in `README.md` (Business Impact).

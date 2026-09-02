# Supply Chain Traceability

**Indonesia - Palm Oil & Agriculture**
Use case: Supply Chain Traceability

> Plantation-to-refinery traceability for the world's largest palm oil producer — Dynamic Tables build chain-of-custody across 300 mills, Iceberg enables buyer self-service via Athena, and Row Access Policies enforce trader-level data segregation.

## Why Snowflake

Snowflake builds plantation-to-refinery chain-of-custody with Dynamic Tables, enables buyer self-service via Iceberg/Athena, and enforces trader-level data segregation — all native SQL, no external blockchain needed

- **Dynamic Tables for real-time chain-of-custody** - Only demo building supply chain traceability with Dynamic Tables at 300-mill scale
- **Iceberg Tables for auditor self-service via Athena** - Only demo enabling external auditor access without Snowflake license
- **Row Access Policies for buyer data segregation** - Only demo enforcing multi-buyer data isolation in supply chain context
- **Indonesian palm oil context at global scale** - ISPO, RSPO, NDPE-specific with 60% global production share context
- **500 audit reports searchable** - Cortex Search on third-party audit findings with severity classification

## What is deployed

| | |
|---|---|
| Database | `ID_PALM_OIL_TRACEABILITY` |
| Service | `ID_PALM_OIL_TRACEABILITY_APP` |
| Compute pool | `SEA_DEMOS_INDONESIA_POOL` |
| Dimension table | `RAW.BUYERS` (20 rows) |
| Fact table | `RAW.CHAIN_OF_CUSTODY` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | IDR (Rp) |

Regions in play: Jakarta, North Sumatra, Riau, East Kalimantan, Sulawesi
Segments: Own Estate, Plasma Scheme, Independent Smallholder, Third-Party Mill

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh ID_PALM_OIL_TRACEABILITY
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Traceability (TTP) | `97.2%` | average per event |
| Traceable to Mill | `100%` | average per event |
| RSPO Certified | `42%` | average per event |
| Smallholders Traced | `84K` | total across Buyers |
| Direct Suppliers | `247` | total across Buyers |
| Collection Points | `1,842` | total across Buyers |
| GPS-Mapped Plots | `124K` | total across Buyers |


## Demo flow

1. Executive Cockpit
2. Chain of Custody
3. Auditor Access
4. Ask AI
5. Architecture & Data

## Talking points

- **300 mills** - tracked across Sumatra and Kalimantan
- **150,000 records** - chain-of-custody entries maintained in real-time
- **97.8% traceable** - volume traceable to smallholder level
- **Rp 142T** - traced export volume this year
- **500 audit reports** - searchable via Cortex Search
- **5,000 smallholders** - in supply chain across Sumatra and Kalimantan

## Business impact

- Indonesia produced 51.3 million tonnes of CPO in 2023 — 60% of global output (GAPKI)
- EU Deforestation Regulation (EUDR) requires full traceability by Dec 2025 for all palm oil imports (European Commission)
- Indonesia has 2.67 million palm oil smallholders managing 41% of planted area (World Bank)
- Traceable palm oil commands 8-15% price premium over non-traceable in EU markets (RSPO)

---
Generated from `generator/demo_specs/aws-indonesia-palm-oil-traceability.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-indonesia-palm-oil-traceability` instead.

# Demo Script: Supply Chain Traceability
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake builds plantation-to-refinery chain-of-custody with Dynamic Tables, enables buyer self-service via Iceberg/Athena, and enforces trader-level data segregation — all native SQL, no external blockchain needed"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Budi Santoso** | VP Supply Chain | React App (SPCS) | End-to-end traceability, EUDR compliance, buyer requirements, deforestation risk |
| **Ratna Dewi** | Sustainability Auditor | Amazon QuickSight | Audit trail integrity, ISPO certification, mass balance reconciliation, deforestation monitoring |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 7 tables | MILLS (300), SHIPMENTS (60000), CHAIN_OF_CUSTODY (150000), CERTIFICATIONS (8000), AUDIT_REPORTS (500), BUYERS (80), SMALLHOLDERS (5000) |
| **CURATED** | 4 Dynamic Tables | FULL_CHAIN_OF_CUSTODY, MILL_TRACEABILITY_SCORE, BUYER_SUPPLY_CHAIN_VIEW, MASS_BALANCE_RECONCILIATION |
| **ML** | ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | AI_PARSE_DOCUMENT, SUMMARIZE, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 500 documents indexed |
| **Agent** | TRACEABILITY_AGENT | Semantic View + Search tools |


---

## The Story

Indonesia produces 60% of the world's palm oil across thousands of mills in Sumatra and Kalimantan. International buyers require full plantation-to-port traceability and NDPE compliance proof under upcoming EUDR regulations. Twelve mills are below the 95% traceability threshold, and mass balance reconciliation flags 7 mills with suspicious variance. With 5,000 smallholders in the supply chain, visibility requires automation at scale.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "Three hundred mills tracked — 97.8% of volume traceable to smallholder level."

**Action**: Point at the 97.8% traceability KPI

### [0:45–1:30] CHAIN OF CUSTODY

**Show**: Chain of Custody tab

> "Full smallholder-to-port chain for every tonne of CPO — built automatically by Dynamic Tables."

**Action**: Click shipment SHP-2024-1247 for full chain visualization

### [1:30–2:15] AUDITOR ACCESS

**Show**: Auditor Access tab

> "Row Access Policies enforce buyer-level data segregation — Wilmar sees only their supply chain."

**Action**: Show Row Access Policy in action — toggle between buyer views

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Budi asks: 'What percentage of our volume is traceable to plantation?'"

**Action**: Type: 'What is our traceability percentage by mill?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Seven Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **Dynamic Tables for real-time chain-of-custody** — Only demo building supply chain traceability with Dynamic Tables at 300-mill scale
2. **Iceberg Tables for auditor self-service via Athena** — Only demo enabling external auditor access without Snowflake license
3. **Row Access Policies for buyer data segregation** — Only demo enforcing multi-buyer data isolation in supply chain context
4. **Indonesian palm oil context at global scale** — ISPO, RSPO, NDPE-specific with 60% global production share context
5. **500 audit reports searchable** — Cortex Search on third-party audit findings with severity classification


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRACEABILITY_ID.RAW.MILLS` → 300
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRACEABILITY_ID.RAW.CHAIN_OF_CUSTODY` → 150000
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRACEABILITY_ID.RAW.SHIPMENTS` → 60000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRACEABILITY_ID.ML.MASS_BALANCE_ANOMALY_RESULTS WHERE IS_ANOMALY = TRUE` → >=7

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRACEABILITY_ID.AI.PARSED_AUDIT_REPORTS` → 500
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRACEABILITY_ID.AI.SHIPMENT_RISK_CLASSIFICATION` → >0


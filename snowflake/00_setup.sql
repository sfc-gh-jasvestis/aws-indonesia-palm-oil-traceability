-- Generated from generator/demo_specs/aws-indonesia-palm-oil-traceability.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-indonesia-palm-oil-traceability
-- This is the schema that is actually deployed for ID_PALM_OIL_TRACEABILITY.

-- ID_PALM_OIL_TRACEABILITY  (Supply Chain Traceability)
-- generated from generator/demo_specs/aws-indonesia-palm-oil-traceability.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS ID_PALM_OIL_TRACEABILITY;
CREATE SCHEMA IF NOT EXISTS ID_PALM_OIL_TRACEABILITY.RAW;
CREATE SCHEMA IF NOT EXISTS ID_PALM_OIL_TRACEABILITY.CURATED;
CREATE SCHEMA IF NOT EXISTS ID_PALM_OIL_TRACEABILITY.APP;
USE DATABASE ID_PALM_OIL_TRACEABILITY;

-- 5 real regions; entity names carry their region so the two always agree

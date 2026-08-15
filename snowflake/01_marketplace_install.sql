-- ============================================================================
-- 01_MARKETPLACE_INSTALL.SQL — Install marketplace data for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA RAW;

-- Free listings to install from Snowflake Marketplace:
-- Install: Snowflake Public Data (Free)
--   https://app.snowflake.com/marketplace/listing/GZTSZ290BV255

-- Paid listing (mock): Global Forest Watch Deforestation Alerts
--   Real data: https://app.snowflake.com/marketplace/listing/GZT0Z5I44YC
--   Using mock table: SMALLHOLDERS
CREATE TABLE IF NOT EXISTS RAW.SMALLHOLDERS (
  ID INT AUTOINCREMENT, DATA VARIANT, LOADED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);


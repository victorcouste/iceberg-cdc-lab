-- =====================================================================================
-- 2. SOURCE CHANGES (simulating on-prem activity)
-- =====================================================================================
-- Note: one multi-row INSERT, not three. Three INSERT statements = three snapshots
-- = 3x the metadata files and S3 PUTs for the same rows.

INSERT INTO onprem.customer_onprem (custkey, name, mktsegment, account_balance, nationkey)
VALUES
    ( 0, 'SPARK',     'ENGINE',     0, 3),
    (-1, 'TRINO',     'SQLENGINE',  1, 4),
    (-2, 'STARBURST', 'ENTERPRISE', 2, 1);

UPDATE onprem.customer_onprem SET account_balance = 1000000 WHERE custkey = 1;
UPDATE onprem.customer_onprem SET account_balance = 2000000 WHERE custkey = 2;
UPDATE onprem.customer_onprem SET account_balance = 3000000 WHERE custkey = 3;

-- A DELETE, which a "$file_modified_time" approach could never detect: it writes no
-- new data file, so the timestamp never surfaces it.
DELETE FROM onprem.customer_onprem WHERE custkey = 4;

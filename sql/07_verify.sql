-- =====================================================================================
-- 7. VERIFY
-- =====================================================================================
SELECT count(*) AS src FROM onprem.customer_onprem;
SELECT count(*) AS tgt FROM cloud.customer_cloud;

-- Full-fidelity check, fine for the lab (sf1 = 150k rows). Do NOT run this on large
-- tables: it reads both tables end to end and defeats the point of incremental CDC.
SELECT 'only_onprem' AS side, * FROM (
    SELECT * FROM onprem.customer_onprem EXCEPT SELECT * FROM cloud.customer_cloud)
UNION ALL
SELECT 'only_cloud', * FROM (
    SELECT * FROM cloud.customer_cloud EXCEPT SELECT * FROM onprem.customer_onprem);

-- Cheap ongoing check: compare a keyed checksum instead.
SELECT checksum(custkey), checksum(account_balance), count(*) FROM onprem.customer_onprem;
SELECT checksum(custkey), checksum(account_balance), count(*) FROM cloud.customer_cloud;

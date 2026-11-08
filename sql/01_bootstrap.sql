-- =====================================================================================
-- 1. BOOTSTRAP -- one full copy, then pin the snapshot that was replicated
-- =====================================================================================
-- This is the only full transfer. Everything after it is delta-only.

DROP TABLE IF EXISTS cloud.customer_cloud;

CREATE TABLE cloud.customer_cloud
WITH (
  format_version = 2,
  merge_mode     = 'copy-on-write'   -- see README: better for Athena/EMR readability
  -- , partitioning = ARRAY['nationkey']   -- consider: narrows the files a MERGE rewrites
) AS
SELECT custkey, name, mktsegment, account_balance, nationkey
FROM onprem.customer_onprem;

-- The replication high-water mark. A TAG is an immutable named reference to a snapshot,
-- and 'retention' protects that snapshot from expire_snapshots -- so the replay point
-- cannot be garbage-collected out from under you.
CREATE OR REPLACE BRANCH repl_hwm
WITH (type = 'TAG', retention = '30d') IN TABLE onprem.customer_onprem;

-- =====================================================================================
-- 3. RESOLVE THE REPLICATION WINDOW -- two pinned snapshot IDs
-- =====================================================================================
-- Pin the upper bound BEFORE reading anything. Without this, writes landing mid-cycle
-- make the window non-deterministic and the run non-replayable.

CREATE OR REPLACE BRANCH repl_running
WITH (type = 'TAG', retention = '30d') IN TABLE onprem.customer_onprem;

-- Read both ends of the window from $refs. In an orchestrator (Airflow / SEP SQL jobs /
-- dbt) feed these in as :lo and :hi. In a plain SQL client, copy the two values and
-- paste them in place of :lo and :hi in the following scripts.
SELECT
    MAX(CASE WHEN name = 'repl_hwm'     THEN snapshot_id END) AS lo_snapshot_id,
    MAX(CASE WHEN name = 'repl_running' THEN snapshot_id END) AS hi_snapshot_id
FROM "onprem.customer_onprem$refs"
WHERE type = 'TAG';

-- Cheap pre-flight: skip the whole cycle if nothing changed.
SELECT count(*) AS snapshots_in_window
FROM "onprem.customer_onprem$snapshots"
WHERE snapshot_id <> :lo;   -- refine against $history for true ancestry

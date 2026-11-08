-- =====================================================================================
-- 6. COMMIT THE WATERMARK -- only after the MERGE succeeds
-- =====================================================================================
-- Advancing the tag is the single act that makes the cycle durable. If anything before
-- failed, repl_hwm still points at the last good snapshot and a rerun replays the
-- identical window.
--
-- Replace :hi with the hi_snapshot_id from 03_resolve_window.sql.

CREATE OR REPLACE BRANCH repl_hwm
WITH (type = 'TAG', snapshot_id = :hi, retention = '30d') IN TABLE onprem.customer_onprem;

DROP BRANCH repl_running IN TABLE onprem.customer_onprem;
DROP VIEW IF EXISTS onprem.customer_changes;

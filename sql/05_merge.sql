-- =====================================================================================
-- 5. APPLY -- ONE MERGE, ONE COMMIT
-- =====================================================================================
-- The inner query collapses the window to one row per key (last change wins).
-- This is not optional: MERGE fails if a target row matches more than one source row,
-- and a key updated twice inside the window produces exactly that.
--
-- update_before rows are discarded -- they describe the old value, not the new one.

MERGE INTO cloud.customer_cloud AS t
USING (
    SELECT custkey, name, mktsegment, account_balance, nationkey, _change_type
    FROM (
        SELECT
            custkey, name, mktsegment, account_balance, nationkey, _change_type,
            ROW_NUMBER() OVER (PARTITION BY custkey ORDER BY _change_ordinal DESC) AS rn
        FROM onprem.customer_changes
        WHERE _change_type IN ('insert', 'update_after', 'delete')
    )
    WHERE rn = 1
) AS s
ON t.custkey = s.custkey

WHEN MATCHED AND s._change_type = 'delete' THEN
    DELETE

WHEN MATCHED THEN
    UPDATE SET
        name            = s.name,
        mktsegment      = s.mktsegment,
        account_balance = s.account_balance,
        nationkey       = s.nationkey

WHEN NOT MATCHED AND s._change_type <> 'delete' THEN
    INSERT (custkey, name, mktsegment, account_balance, nationkey)
    VALUES (s.custkey, s.name, s.mktsegment, s.account_balance, s.nationkey);

-- IDEMPOTENCY CHECK: re-run the MERGE above verbatim. The target must be unchanged.
-- That property is what makes the cycle safely replayable after a partial failure --
-- there is no "did it half-apply?" state to reason about.

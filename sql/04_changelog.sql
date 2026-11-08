-- =====================================================================================
-- 4. BUILD THE CHANGELOG ON THE PUBLISHER (on-prem)
-- =====================================================================================
-- Classifies every row-level change between the two snapshots as
-- insert / delete / update_before / update_after. This is SEP's built-in CDC primitive.
--
-- start_snapshot_id is EXCLUSIVE, end_snapshot_id is INCLUSIVE.
-- end must be a descendant of start.
--
-- Replace :lo and :hi with the values returned by 03_resolve_window.sql.

ALTER TABLE onprem.customer_onprem EXECUTE create_changelog_view(
    start_snapshot_id  => :lo,
    end_snapshot_id    => :hi,
    identifier_columns => ARRAY['custkey'],
    view_name          => 'customer_changes'
);

-- Inspect what will cross the network. This should be small.
SELECT _change_type, count(*)
FROM onprem.customer_changes
GROUP BY _change_type
ORDER BY 1;

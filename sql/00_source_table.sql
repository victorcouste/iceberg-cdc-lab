-- =====================================================================================
-- 0. SOURCE TABLE -- copy-on-write is required
-- =====================================================================================
-- Run the whole lab in ONE session: SET SESSION below is session-scoped.
--
-- format_version = 2 is a deliberate choice. See README, "Why format_version 2":
-- v3 gives you row lineage ($row_id, $last_updated_sequence_number) but the docs also
-- state v3 is experimental and that row-level updates, deletes and OPTIMIZE are not
-- supported on it -- which is most of what this pipeline does.

SET SESSION skip_results_cache = true;

DROP TABLE IF EXISTS onprem.customer_onprem;

CREATE TABLE onprem.customer_onprem
WITH (
  format_version = 2,
  merge_mode     = 'copy-on-write'   -- REQUIRED by create_changelog_view
) AS
SELECT
    custkey,
    name,
    mktsegment,
    ROUND(acctbal) AS account_balance,
    nationkey
FROM tpch.sf1.customer;

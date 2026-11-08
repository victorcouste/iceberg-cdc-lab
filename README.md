# Iceberg CDC lab

Incremental replication of an Iceberg table from one cluster to another, in plain SQL.
The lab copies a table once, makes changes on the source (inserts, updates, a delete),
then replicates only those changes with a single `MERGE`.

Written for Starburst Enterprise (SEP). Everything runs on the TPC-H sample data, so you
need no data of your own.

## What it demonstrates

- **Snapshot-based change detection.** The window of changes is bounded by two Iceberg
  snapshot IDs pinned with tags, not by timestamps. A run can be replayed and gives the
  same result.
- **Deletes are captured.** `create_changelog_view` classifies each row change as
  `insert`, `delete`, `update_before` or `update_after`. A timestamp watermark never
  sees a delete, because a delete writes no new data file.
- **One commit per cycle.** A single `MERGE` produces one Iceberg snapshot on the target,
  instead of row-by-row DML.
- **Idempotent apply.** Re-running the `MERGE` leaves the target unchanged.
- **Maintenance.** Compaction, manifest clustering, snapshot expiry and orphan file
  removal, which keep storage and S3 request costs under control.

## How it works

```
 source table (onprem.customer_onprem, copy-on-write)
   │  tag repl_hwm      = last replicated snapshot  (lo, exclusive)
   │  tag repl_running  = snapshot pinned for this cycle (hi, inclusive)
   ▼
 create_changelog_view(lo, hi)  →  onprem.customer_changes
   │  keep the last change per key, drop update_before
   ▼
 MERGE INTO cloud.customer_cloud      (one statement, one commit)
   ▼
 move repl_hwm to hi, drop repl_running and the view
```

If a step fails before the last one, `repl_hwm` still points at the last good snapshot
and the next run replays the same window.

## Prerequisites

- A Starburst Enterprise cluster with an Iceberg catalog and the `tpch` catalog.
  Two clusters (on-prem plus cloud, linked by a Stargate catalog) match the real
  scenario. One cluster is enough to try the logic.
- The SQL uses `onprem.` and `cloud.` as prefixes. For a single cluster, create two
  schemas with those names in your Iceberg catalog and select that catalog before
  running the scripts. For two clusters, replace the prefixes with your own catalogs
  and schemas (`cloud` on AWS with Glue and S3, `onprem` reached through Stargate).
- Run all scripts in **one session**: `SET SESSION skip_results_cache = true` in step 0
  is session-scoped.

## Running the lab

Run the scripts in `sql/` in order.

| Script | Step |
|---|---|
| `00_source_table.sql` | Create the source table (copy-on-write, format v2) from `tpch.sf1.customer` |
| `01_bootstrap.sql` | Full copy to the target, pin `repl_hwm` |
| `02_source_changes.sql` | 3 inserts, 3 updates, 1 delete on the source |
| `03_resolve_window.sql` | Pin `repl_running`, read the two snapshot IDs |
| `04_changelog.sql` | Build the changelog view between the two snapshots |
| `05_merge.sql` | Apply the delta to the target with one `MERGE` |
| `06_commit_watermark.sql` | Advance `repl_hwm`, clean up |
| `07_verify.sql` | Row counts, `EXCEPT` diff, checksums |
| `08_maintenance.sql` | Optimize, expire snapshots, remove orphan files |
| `appendix_a_row_lineage.sql` | Variant: Iceberg v3 row-lineage watermark |
| `appendix_b_branch_commit.sql` | Variant: branch as a multi-statement commit unit |

### The `:lo` and `:hi` placeholders

Steps 3, 4 and 6 use `:lo` and `:hi`. An orchestrator (Airflow, SEP SQL jobs, dbt) can
bind them. In a SQL client, run the `SELECT` in `03_resolve_window.sql`, then paste the
two snapshot IDs in place of the placeholders in `03`, `04` and `06`.

### Things to try

- After `05_merge.sql`, run it a second time and check with `07_verify.sql` that nothing
  changed (idempotency).
- Update the same `custkey` twice before step 3 and see why the `ROW_NUMBER()` in the
  `MERGE` is needed.
- Run `02_source_changes.sql` again, then run steps 3 to 6 a second time. The window now
  starts at the snapshot that `repl_hwm` was moved to.
- Run `08_maintenance.sql` and watch `$files` and `$snapshots` on the target.
- Run `EXPLAIN ANALYZE` on the `MERGE` (see note 6 below).

## Design notes and constraints

1. **Copy-on-write is mandatory on the source.** `create_changelog_view` does not work on
   merge-on-read tables. This is the hardest constraint of the design.
2. **The view reads metadata for every snapshot between `:lo` and `:hi`.** If one of them
   was expired, queries on the view fail. That is why the tags carry a retention, and why
   the replication interval must stay shorter than the snapshot retention window.
3. **`identifier_columns` must identify a row uniquely**, be `NOT NULL`, and cannot be
   `REAL` or `DOUBLE`. Check with:
   ```sql
   SELECT custkey, count(*) FROM onprem.customer_onprem
   GROUP BY custkey HAVING count(*) > 1;
   ```
4. **The changelog view is a persistent catalog object.** Use a unique `view_name` per
   concurrent run, or runs overwrite each other.
5. **Why `format_version = 2`.** Iceberg v3 adds row lineage (`$row_id`,
   `$last_updated_sequence_number`), but the docs describe v3 as experimental, with
   row-level updates, deletes and `OPTIMIZE` not supported on it. Those are most of what
   this pipeline does. Appendix A shows the lineage variant and why it still misses deletes.
6. **Measure the network cost.** Run `EXPLAIN ANALYZE` on the `MERGE` and confirm that the
   predicate is pushed down through Stargate and that only the delta crosses the network,
   not the whole source table pulled over for a local semi-join. The whole design relies
   on this, and it is the main thing to measure.
7. **Not yet checked against the docs:** the `table_changes` "Limitations" section and the
   v3 "Format versions" section of the Iceberg connector documentation were not read when
   this was written. Read both before choosing a format version or relying on changelog
   semantics at scale.
8. **The full-table `EXCEPT` check in `07_verify.sql` is for the lab only.** On large
   tables use the keyed checksums.

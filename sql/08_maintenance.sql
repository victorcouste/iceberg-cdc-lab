-- =====================================================================================
-- 8. MAINTENANCE -- this is where the storage bill is actually controlled
-- =====================================================================================
-- Run on a schedule, on BOTH sides. Without it, an incremental pipeline accumulates
-- small files and snapshots indefinitely.

-- Compact small files. Every MERGE cycle adds files; this folds them back together.
ALTER TABLE cloud.customer_cloud EXECUTE optimize(file_size_threshold => '128MB');

-- Cluster manifests so scan planning does not read hundreds of tiny manifest files.
ALTER TABLE cloud.customer_cloud EXECUTE optimize_manifests;

-- Drop old snapshots + their data files, and shrink table metadata.
-- retention_threshold must be >= iceberg.expire-snapshots.min-retention (default 7d).
-- Snapshots pinned by a TAG with a retention are protected from this.
ALTER TABLE cloud.customer_cloud EXECUTE expire_snapshots(
    retention_threshold    => '7d',
    clean_expired_metadata => true);

ALTER TABLE onprem.customer_onprem EXECUTE expire_snapshots(retention_threshold => '7d');

-- Delete files no longer referenced by any live snapshot.
ALTER TABLE cloud.customer_cloud EXECUTE remove_orphan_files(retention_threshold => '7d');

-- Watch file counts and average file size over time. If avg file size trends toward
-- a few MB, compaction is not keeping up with the refresh frequency.
SELECT count(*) AS files, avg(file_size_in_bytes) AS avg_bytes
FROM "cloud.customer_cloud$files";

SELECT count(*) AS snapshot_count FROM "cloud.customer_cloud$snapshots";

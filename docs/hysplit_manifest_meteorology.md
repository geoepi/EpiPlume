# Manifest-wide HYSPLIT meteorology

`plan_hysplit_manifest_meteorology()` converts selected manifest rows into a run-to-file table and a deduplicated unique-file table. The current `reanalysis` adapter delegates monthly filename selection to splitr, so all May 2020 runs requiring the same month use `RP202005.gbl`.

`prepare_hysplit_manifest_meteorology()` inventories the shared cache once, reuses non-empty readable files, and optionally acquires each missing unique file once. It writes CSV and RDS plan, unique-file, inventory, and run-readiness products below the configured ignored meteorology directory. Checksums and byte sizes are retained in the inventory. With `allow_download = FALSE`, preparation is verification-only.

Run readiness records required, verified, and missing file counts. The controlled `_targets_hysplit.R` graph has the dependency `selected manifest rows -> plan/cache preparation -> readiness assertion -> dynamic HYSPLIT branches`; the ordinary `_targets.R` graph remains non-executing. Use the explicit command:

```text
Rscript scripts/prepare_hysplit_manifest_meteorology.R --config config/facility_exchange_demo.yml --manifest local/facility_exchange_demo/manifests/hysplit_run_manifest.csv --no-download
```

Add `--allow-download` only when acquisition is authorized. `--run-ids A,B` limits preparation while preserving manifest order. A lock directory under the cache prevents concurrent acquisition. A stale lock can be removed after inspecting its `owner` file and confirming the owning process is gone.

The downloader and filename selection remain isolated behind splitr's installed internal `get_monthly_filenames()` and `download_met_files()` helpers. This is an intentional compatibility boundary and should be retested when splitr changes.

# HYSPLIT meteorology cache design

Meteorology is an explicit, shared preparation stage rather than an implicit side effect of model execution:

```text
manifest date coverage
→ unique required meteorological files
→ acquire once
→ verify and checksum
→ shared read-only cache
→ multiple HYSPLIT runs
```

The smoke configuration may opt into acquisition with `allow_meteorology_download: true`; the general demonstration configuration defaults this flag to `false`. `HYSPLIT_METEOROLOGY_DIRECTORY` overrides the configuration path. When both are absent, only the single-run smoke scenario uses its ignored local fallback cache.

Manifest-wide preparation uses the same splitr compatibility wrappers, but plans all selected runs first. Identical monthly files are collapsed into one cache requirement, acquired once, checksum- and size-verified, and mapped back to a per-run readiness table. The controlled multi-run targets graph asserts that every selected run is ready before dynamic execution branches are allowed to start. Downloads are never performed by individual workers.

Preparation creates a `.meteorology_download.lock` directory while acquiring files. An active lock fails a second preparation process; if a process is killed, inspect the owner file and remove the stale lock only after confirming that no preparation remains active.

The installed `splitr` version used by this branch is `0.4.0.9000`. For `reanalysis`, the adapter uses splitr's internal `get_monthly_filenames()` selection and `download_met_files()` downloader, the same path called by `hysplit_dispersion()`. It therefore requests the splitr-native `RPYYYYMON.gbl` files without launching HYSPLIT. The cache writes CSV and RDS inventories containing relative/absolute paths, sizes, modification times, MD5 checksums, acquisition status, run ID, simulation bounds, verification status, and coverage status.

Production runs must acquire and verify a shared cache before parallel model workers start. Individual workers must not independently download the same meteorological files.

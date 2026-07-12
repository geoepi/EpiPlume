# Controlled single-run HYSPLIT smoke test

This procedure executes exactly one synthetic source/release row. It does not use facility data, install HYSPLIT, or enable execution from `_targets.R`. Meteorology is prepared explicitly before execution and may be downloaded only when the smoke acquisition command is given `--allow-download`.

## Prerequisites

Install R packages used by the project, `splitr`, `sf`, `terra`, `yaml`, and `jsonlite`. Provide a local HYSPLIT installation containing the executable files expected by the repository adapter: `hycs_std` and `parhplot` (with `.exe` suffix on Windows). `splitr`'s bundled platform directory is accepted when available. Meteorology is cached under `HYSPLIT_METEOROLOGY_DIRECTORY`, the configured directory, or the ignored smoke fallback `local/facility_exchange_single_run_smoke/meteorology`.

Set `HYSPLIT_INSTALL_DIRECTORY` and `HYSPLIT_METEOROLOGY_DIRECTORY`; machine-specific values must not be committed. The smoke execution additionally requires `EPIPLUME_RUN_IDS=<RUN_ID>` and `EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true`.

## Procedure

Run `Rscript scripts/setup_facility_exchange_demo.R` if the local synthetic planning products are needed. Prepare one selected row explicitly:

```text
Rscript scripts/prepare_hysplit_meteorology.R --config config/facility_exchange_smoke.yml --run-id F001__20200501T000000Z --allow-download
```

This uses splitr 0.4.0.9000's native reanalysis file selection/download path, reuses cached `RPYYYYMON.gbl` files, and writes `meteorology_inventory.csv` and `meteorology_inventory.rds`. It never launches a HYSPLIT executable. For offline cache reuse use `--no-download`.

Then run:

```text
Rscript scripts/preflight_hysplit_single_run.R --config config/facility_exchange_smoke.yml --run-id <RUN_ID>
```

Preflight resolves the installation and verifies the prepared local meteorology, validates the row, prints the complete specification, and refuses a non-empty run directory. `--prepare-meteorology` is available for an explicit combined preparation/preflight, but the preferred sequence is two separate commands. After preflight passes:

```text
EPIPLUME_RUN_IDS=<RUN_ID> EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true Rscript scripts/run_hysplit_single_run_smoke.R --config config/facility_exchange_smoke.yml --run-id <RUN_ID> --authorize-execution
Rscript scripts/summarize_hysplit_single_run_smoke.R --config config/facility_exchange_smoke.yml --run-id <RUN_ID>
Rscript scripts/run_facility_exchange_pipeline.R --config config/facility_exchange_smoke.yml
```

On Windows, set the two environment variables with `$env:...` before invoking `Rscript`. Execution logs `meteorology acquisition during model execution: not requested`; verified files must already exist. The run creates standardized metadata, parsed dispersion/raster products, and receptor/exchange products below ignored `local/` output. The ordinary targets graph discovers completed products and never invokes HYSPLIT or downloads meteorology; a second pipeline invocation should report all targets up to date.

## Failure diagnosis

The first failing boundary is reported by the script: executable resolution, meteorology resolution, control-file/model execution, output discovery, parsing, rasterization, or receptor extraction. Preserve the run directory and its control/stdout/stderr files. Correct one boundary at a time and rerun only after explicitly reviewing the isolated directory.

## Results

The real-run result is recorded in the local smoke summary and is intentionally not committed. At the time of implementation, splitr resolved to `0.4.0.9000`, but the real run remained blocked until a compatible meteorological cache was prepared; the exact preflight failure was a missing `HYSPLIT_METEOROLOGY_DIRECTORY`. Downloaded files and all generated products remain below ignored `local/` paths.

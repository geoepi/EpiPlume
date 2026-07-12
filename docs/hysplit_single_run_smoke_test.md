# Controlled single-run HYSPLIT smoke test

This procedure executes exactly one synthetic source/release row. It does not use facility data, download meteorology, install HYSPLIT, or enable execution from `_targets.R`.

## Prerequisites

Install R packages used by the project, `splitr`, `sf`, `terra`, `yaml`, and `jsonlite`. Provide a local HYSPLIT installation containing the executable files expected by the repository adapter: `hycs_std` and `parhplot` (with `.exe` suffix on Windows). `splitr`'s bundled platform directory is accepted when available. Provide compatible local meteorological files in a directory selected by `HYSPLIT_METEOROLOGY_DIRECTORY`.

Set `HYSPLIT_INSTALL_DIRECTORY` and `HYSPLIT_METEOROLOGY_DIRECTORY`; machine-specific values must not be committed. The smoke execution additionally requires `EPIPLUME_RUN_IDS=<RUN_ID>` and `EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true`.

## Procedure

Run `Rscript scripts/setup_facility_exchange_demo.R` if the local synthetic planning products are needed. Select one ID from the generated manifest, then run:

```text
Rscript scripts/preflight_hysplit_single_run.R --config config/facility_exchange_smoke.yml --run-id <RUN_ID>
```

Preflight resolves the installation and local meteorology, validates the row, prints the complete specification, and refuses a non-empty run directory. After it passes:

```text
EPIPLUME_RUN_IDS=<RUN_ID> EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true Rscript scripts/run_hysplit_single_run_smoke.R --config config/facility_exchange_smoke.yml --run-id <RUN_ID> --authorize-execution
Rscript scripts/summarize_hysplit_single_run_smoke.R --config config/facility_exchange_smoke.yml --run-id <RUN_ID>
Rscript scripts/run_facility_exchange_pipeline.R --config config/facility_exchange_smoke.yml
```

On Windows, set the two environment variables with `$env:...` before invoking `Rscript`. The run creates standardized metadata, parsed dispersion/raster products, and receptor/exchange products below ignored `local/` output. The ordinary targets graph discovers completed products and never invokes HYSPLIT; a second pipeline invocation should report all targets up to date.

## Failure diagnosis

The first failing boundary is reported by the script: executable resolution, meteorology resolution, control-file/model execution, output discovery, parsing, rasterization, or receptor extraction. Preserve the run directory and its control/stdout/stderr files. Correct one boundary at a time and rerun only after explicitly reviewing the isolated directory.

## Results

The real-run result is recorded in the local smoke summary and is intentionally not committed. If local HYSPLIT binaries or compatible meteorology are unavailable, the branch can be verified with the non-executing tests and mock parser/receptor fixtures, but it is not ready to claim a completed real smoke test.

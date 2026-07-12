# Single-run HYSPLIT manifest adapter

## Purpose and scope

The adapter translates exactly one source and one release from the facility-exchange manifest into the argument contract of the existing `run_plume_model()` function. It does not iterate over a manifest, download meteorology, calculate receptor exposure, aggregate rasters, or attribute sources. The configured 20 km evaluation threshold is downstream analysis metadata and does not stop HYSPLIT.

## Existing execution interface

`wrap_plume_model(cfg, save = TRUE, ..., core_fun = run_plume_model)` assembles configuration values and accepts argument overrides. Its underlying executor is:

```r
run_plume_model(
  plume_name, lon, lat, height, rate, pdiam, density, shape_factor,
  release_start, release_end, start_time, end_time, direction,
  met_type, met_dir, exec_dir, clean_up
)
```

It returns the executed `splitr` dispersion-model object. The adapter calls this underlying function and does not duplicate its HYSPLIT logic. Existing wrappers and demonstrations are unchanged.

## Validation and discovery

`validate_hysplit_manifest_row()` accepts a one-row data frame or named list, validates identifiers, coordinates, positive physical inputs, status, and UTC time ordering, and returns UTC `POSIXct` fields. `resolve_hysplit_executable()` checks configuration first and then `HYSPLIT_EXECUTABLE`. The existing `splitr` executor does not accept an executable argument, so the resolved file is validated and recorded as provenance while `splitr` retains responsibility for executable discovery.

`resolve_hysplit_meteorology()` only inspects the configured local directory. No repository convention proves temporal coverage from filenames, so existing candidate files receive `coverage_status = "unknown"`; absent files receive `"missing"`. Nothing is downloaded.

## Dry-run and execution

```r
cfg <- read_facility_exchange_config()
manifest <- read.csv("local/facility_exchange_demo/manifests/hysplit_run_manifest.csv")
dry_result <- run_hysplit_manifest_row(manifest[1, ], cfg, dry_run = TRUE)
```

Dry-run validates and returns a deterministic run specification and expected paths without creating directories or calling HYSPLIT. Execution requires a real executable and at least one local meteorological candidate, prevents reuse of a nonempty directory unless `overwrite = TRUE`, and invokes `run_plume_model()` (or an injected test function). Runtime errors produce a structured `failed` result rather than being rethrown.

Attempted execution writes `<run_directory>/run_metadata.rds` and `<run_directory>/run_metadata.json`, including timing, warnings, errors, inputs, paths, commit SHA, and status. The RDS retains the model object; JSON replaces it with a class summary.

## Command line

```bash
Rscript scripts/run_facility_exchange_case.R \
  --manifest local/facility_exchange_demo/manifests/hysplit_run_manifest.csv \
  --run-id F001__20200501T000000Z \
  --config config/facility_exchange_demo.yml \
  --dry-run
```

Exactly one of `--dry-run` and `--execute` is required. `--overwrite` only affects execution. Invalid input and failed execution return a nonzero exit code.

## Schemas and limitations

The input schema is defined by `validate_hysplit_manifest_row()`. The run specification uses the exact core argument names under `core_args`; result schema version `1.0.0` contains run identity, UTC times, meteorology diagnostics, expected and actual files, timing, warnings, errors, provenance, the complete specification, and the model result.

This adapter handles one source and one release only. It does not prove meteorological temporal coverage, calculate receptor exposure, parse completed plume output, or implement full-manifest iteration. The next integration step is post-run standardization of one completed plume result.

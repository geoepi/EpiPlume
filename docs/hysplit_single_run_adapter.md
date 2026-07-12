# Single-run HYSPLIT manifest adapter

## Purpose and scope

The adapter translates exactly one source and one release from the facility-exchange manifest into the argument contract of the existing `run_plume_model()` function. It does not iterate over a manifest, download meteorology, calculate receptor exposure, aggregate rasters, or attribute sources. The configured 20 km evaluation threshold is downstream analysis metadata and does not stop HYSPLIT.

## Existing execution interface

`wrap_plume_model(cfg, save = TRUE, ..., core_fun = run_plume_model)` assembles configuration values and accepts argument overrides. Its underlying executor is:

```r
run_plume_model(
  plume_name, lon, lat, height, rate, pdiam, density, shape_factor,
  release_start, release_end, start_time, end_time, direction,
  met_type, met_dir, exec_dir, clean_up, binary_path = NULL
)
```

It returns the executed `splitr` dispersion-model object. The adapter calls this underlying function and does not duplicate its HYSPLIT logic. Adding the optional trailing `binary_path` argument is backward-compatible with the existing wrapper and demonstrations.

## Audited splitr contract

The installed package is `splitr` **0.4.0.9000**. Inspection of the installed `add_dispersion_params()`, `run_model()`, `hysplit_dispersion()`, `set_binary_path()`, and `hysplit_config_init()` implementations established the following:

- `exec_dir` is a run working directory, not an executable or general output directory. `splitr` changes into it for execution and writes native files such as `SETUP.CFG`, `ASCDATA.CFG`, `CONTROL`, `PARDUMP`, and `GIS_part_*` products there.
- `binary_path` is a directory prefix. `splitr` appends `hycs_std` and `parhplot` (with platform suffixes as applicable). When it is `NULL`, `splitr` selects platform-specific binaries bundled in its installed package under `win`, `osx`, or `linux-amd64`.
- `run_model()` returns the dispersion model with `disp_df`; it does not save the R model object. The legacy `wrap_plume_model(save = TRUE)` separately saves `<plume_name>_model.rds` beneath its configured `exec_dir`.
- `clean_up = TRUE` deletes files in `exec_dir`. Executable installation and per-run working storage therefore must be distinct. This adapter also separates its metadata output directory from the `splitr` working directory.

## Validation and discovery

`validate_hysplit_manifest_row()` accepts a one-row data frame or named list, validates identifiers, coordinates, positive physical inputs, status, and UTC time ordering, and returns UTC `POSIXct` fields. `resolve_hysplit_installation()` checks `hysplit_install_directory`, then `HYSPLIT_INSTALL_DIRECTORY`, then the platform directory bundled with `splitr`. It validates both required binaries and passes the resolved directory to `run_plume_model(binary_path = ...)`; no resolved installation path is provenance-only.

The path model is explicit: `hysplit_install_directory` stores binaries; `meteorology_directory` stores local meteorology; `run_root_directory` is the parent of manifest run directories; `run_directory` identifies one deterministic source/release case; `working_directory` is `<run_directory>/splitr_work` and maps to `exec_dir`; and `output_directory` is the run directory where adapter metadata is retained.

`resolve_hysplit_meteorology()` only inspects the configured local directory. No repository convention proves temporal coverage from filenames, so existing candidate files receive `coverage_status = "unknown"`; absent files receive `"missing"`. Nothing is downloaded.

## Dry-run and execution

```r
cfg <- read_facility_exchange_config()
manifest <- read.csv("local/facility_exchange_demo/manifests/hysplit_run_manifest.csv")
dry_result <- run_hysplit_manifest_row(manifest[1, ], cfg, dry_run = TRUE)
```

Dry-run validates and returns a deterministic run specification and expected paths without creating directories or calling HYSPLIT. Execution requires a real executable and at least one local meteorological candidate, prevents reuse of a nonempty directory unless `overwrite = TRUE`, and invokes `run_plume_model()` (or an injected test function). Runtime errors produce a structured `failed` result rather than being rethrown.

Attempted execution inventories native and adapter outputs before persistence, including both metadata files in `actual_output_files`, writes JSON, and then writes the complete RDS object. The RDS retains the model object; JSON replaces it with a class summary. If JSON serialization fails, the adapter records a metadata warning, excludes the absent JSON path from the final inventory, and still writes complete RDS metadata. This does not change the model execution status.

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

This adapter handles one source and one release only. It does not prove meteorological temporal coverage, calculate receptor exposure, parse completed plume output, or implement full-manifest iteration. Although the adapter pre-validates local candidates, `splitr` itself calls its meteorology getter during real execution; a smoke test therefore also requires compatible files with the exact names expected by `splitr`. The next integration step is post-run standardization of one completed plume result.

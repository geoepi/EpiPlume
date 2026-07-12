# HYSPLIT plume-output parsing

This workflow parses one completed atmospheric-tracer run. It does not run HYSPLIT, download meteorology, calculate receptor exposure, iterate across a manifest, or estimate infection or transmission probability.

## Observed splitr structure and mapping

Saved `splitr 0.4.0.9000` `dispersion_model` objects contain `disp_df`. The observed table has `particle_i`, `hour`, `lat`, `lon`, and `height`; no mass, concentration, or absolute timestamp is present. The canonical mapping is:

| splitr column | Canonical column | Rule |
|---|---|---|
| `particle_i` | `particle_id` | Preserved as character. |
| `hour` | `elapsed_hours` | Numeric elapsed-hour index. |
| `hour` plus run release time | `datetime_utc` | Release time plus elapsed hours, in UTC. |
| `lon`, `lat` | `longitude`, `latitude` | Numeric WGS84 coordinates. |
| `height` | `height_m` | Numeric height in metres. |
| absent | `raw_mass`, `raw_concentration` | Explicit `NA_real_`. |

Compatible fixtures may provide unambiguous `mass`, `concentration`, or explicit datetime columns. Every original column is retained with an `original_` prefix, and mapping diagnostics are attached. Ambiguous aliases fail rather than being guessed.

## Transformations

Raw values remain unchanged. Exponential tracer decay uses the configured half-life and adds the retained fraction plus independently decayed mass and concentration. The 20 km evaluation radius is a separate post-run distance annotation/filter and never stops HYSPLIT.

The raster template uses a local UTM CRS, is centered on the source, extends through the evaluation radius plus computational buffer, and uses metre-based configured resolution. Records are assigned to bins `[hour, hour + 1)` using `floor(elapsed_hours)`. Particle counts use sums and zero in unoccupied cells. Mass uses sums; concentration uses means because concentration is an intensive quantity. Quantity layers use `NA` for unoccupied cells and preserve `NA` when all records in an occupied cell lack that quantity. No smoothing or interpolation is performed.

## Outputs and diagnostics

`parse_hysplit_run_output()` returns the raw and canonical tables, filtered table, template, supported hourly raster stacks, layer metadata, one-row plume summary, and parsing metadata. With writing enabled, `parsed/` contains RDS/CSV tables, supported GeoTIFFs, layer metadata, summary, and RDS/JSON parsing metadata. The inventory records checksums for non-metadata products, package versions, and repository commit; self-checksums are intentionally `NA` to avoid recursion.

Dry-run, failed, missing, malformed, and unsupported model results fail clearly. Small transparent fixtures cover complete, mass-only, concentration-only, malformed coordinate, missing identifier/time, and beyond-20-km cases. Current limitations are the absence of mass/concentration in native `splitr` particle output, no native-file re-reading, no receptor sampling, and no multi-run orchestration.

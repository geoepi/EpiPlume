# Facility receptor extraction

This workflow samples one completed parsed plume and produces one record for each directed source-to-receptor pair. An intercept means modeled atmospheric-tracer contact under the configured sampling and threshold rule; it does not mean infection or transmission. The workflow does not run HYSPLIT or iterate across runs.

Facilities are stored in EPSG:4326 and transformed to the source-local UTM CRS for distances and metre-based buffers. Point sampling returns the containing raster-cell value. Buffer sampling calls `terra::extract(..., exact = TRUE)`: polygon overlap fractions are used with the configured summary. Counts and mass default to overlap-aware sums; concentration defaults to an overlap-aware mean because concentration is intensive.

Hourly values retain zero as modeled zero exposure. `NA` identifies unavailable metrics, receptors outside the raster, or receptors screened outside the evaluation radius. Raw and tracer-decayed mass/concentration remain separate. Concentration cumulative values are labeled hourly-sum indices because physical temporal-integration units have not been established.

The configured intercept metric defaults to particle count. A receptor is an intercept when its sampled value meets or exceeds the threshold in at least `minimum_intercept_hours` bins. Timing uses explicit `[bin_start, bin_end)` metadata: first arrival is the first threshold-meeting bin, last exposure is the end of the last positive bin, and exposure duration is the sum of positive bin widths. Non-intercept reasons distinguish threshold failure, zero modeled exposure, distance screening, raster extent, and unavailable metrics.

The exchange schema retains run/source/receptor identity, UTC run bounds, coordinates, distance, sampling settings, intercept classification and timing, positive-hour count, and maximum/cumulative raw and decayed particle, mass, and concentration metrics. Writing creates receptor metadata, sampled time series, metric summaries, exchange CSV, and checksummed RDS/JSON metadata beneath `<run_directory>/receptors/`.

Current limitations are one parsed run at a time, raster-based sampling only, no source attribution across runs, no receptor-height model, and no epidemiological interpretation.

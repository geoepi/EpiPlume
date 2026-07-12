# Facility exchange workflow plan

## Scope

This foundation creates reproducible synthetic facilities and monitoring observations, identifies directed source–receptor candidates within a projected 20 km radius, applies a configurable exponential tracer-decay calculation, and writes a planning-only HYSPLIT run manifest.

The workflow does not execute HYSPLIT, retrieve meteorology, represent a pathogen, estimate epidemiological transmission, or use real facility records.

## Workflow

1. Read and validate `config/facility_exchange_demo.yml`.
2. Create local ignored output directories.
3. Generate 120 spatially clustered synthetic facilities in a local UTM projection and return longitude/latitude records.
4. Generate reproducible positive, negative, and unknown monitoring observations plus separate simulation truth.
5. calculate projected source-to-receptor distances and retain directed pairs within the configured evaluation radius.
6. Create one planned manifest row per selected source and release time. The four configured releases are metadata only.
7. Apply `V(t) = exp(-log(2) t / h)` to future elapsed-time tracer products, where `h` is the configured half-life.

Run `source("scripts/setup_facility_exchange_demo.R")` from the repository root. Generated CSV files remain below `local/facility_exchange_demo/` and are not versioned.

## Future adapter boundary

A later HYSPLIT adapter may consume the manifest and meteorological files supplied by the user. It should write raw dispersion output separately from evaluated tracer-exchange products and preserve the continuous concentration and viability values. Execution and downloading are deliberately outside this foundation.

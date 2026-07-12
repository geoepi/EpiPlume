# Restartable HYSPLIT manifest execution

`run_hysplit_manifest_subset()` executes an explicitly selected manifest subset after shared meteorology has been verified. Durable states are `planned`, `meteorology_blocked`, `ready`, `running`, `completed`, `execution_failed`, `parse_failed`, `receptor_failed`, `invalid`, and `skipped_completed`.

Each run retains its own metadata, parsed products, and receptor products. A completed run is skipped only when its completed metadata and both durable downstream outputs exist. Failed runs require `retry_failed = TRUE`; ambiguous nonempty directories require manual recovery.

The scenario `execution/` directory contains atomically replaced CSV and RDS ledgers. Attempts are incremented only when HYSPLIT execution starts; parse-only and receptor-only resumes do not change the attempt count. A `.execution.lock/owner` directory prevents duplicate local execution and records run, process, host, timestamp, and commit. The adapter recognizes this lock as coordination metadata while continuing to reject every unrelated entry in a new run directory. Lock removal is never automatic based on age; inspect it and use `clear_stale_hysplit_run_lock.R --run-id ID --run-directory PATH --confirm` only after verifying ownership.

Sequential execution is the default. `workers` is bounded by the selected execution count. Windows uses a PSOCK cluster, and result processing remains in manifest order. Workers do not prepare or download meteorology. The parent process owns local ledger updates, so this ledger is not safe for unrelated independent OS processes or SLURM tasks writing concurrently. Future SLURM support requires an interprocess ledger lock or per-run ledger shards followed by a deterministic merge.

Completed execution metadata with missing parsed products resumes parsing without rerunning HYSPLIT. Completed metadata and parsed products with missing receptor products resumes receptor extraction only. Failed model execution requires `retry_failed = TRUE`. A full-manifest CLI run additionally requires `--authorize-full-manifest`.

Durable parsed plume RDS files store `terra` rasters as `PackedSpatRaster` objects. Receptor sampling unwraps them after loading, allowing postprocessing and ordinary-pipeline ingestion in a later R process without invalid external pointers.

The ordinary `_targets.R` pipeline remains planning/ingestion-only. Completed products are discovered and assembled by the existing inventory functions; HYSPLIT is launched only by an explicitly authorized runner or the controlled execution graph.

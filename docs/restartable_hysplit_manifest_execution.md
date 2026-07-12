# Restartable HYSPLIT manifest execution

`run_hysplit_manifest_subset()` executes an explicitly selected manifest subset after shared meteorology has been verified. Durable states are `planned`, `meteorology_blocked`, `ready`, `running`, `completed`, `execution_failed`, `parse_failed`, `receptor_failed`, `invalid`, and `skipped_completed`.

Each run retains its own metadata, parsed products, and receptor products. A completed run is skipped only when its completed metadata and both durable downstream outputs exist. Failed runs require `retry_failed = TRUE`; ambiguous nonempty directories require manual recovery.

The scenario `execution/` directory contains atomically replaced CSV and RDS ledgers. Attempts are incremented when an execution starts and prior successful rows are retained. A `.execution.lock/owner` directory prevents duplicate local execution and records run, process, host, timestamp, and commit. Lock removal is never automatic based on age; inspect it and use `clear_stale_hysplit_run_lock.R --run-id ID --run-directory PATH --confirm` only after verifying ownership.

Sequential execution is the default. `workers` is bounded by the selected run count; the first implementation keeps ledger coordination in the parent process and is compatible with later SLURM array mapping because run IDs and directories are independent.

The ordinary `_targets.R` pipeline remains planning/ingestion-only. Completed products are discovered and assembled by the existing inventory functions; HYSPLIT is launched only by an explicitly authorized runner or the controlled execution graph.

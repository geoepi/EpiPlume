# Controlled multi-run HYSPLIT smoke test

This workflow executes an explicitly selected set of two to six manifest rows sequentially. The runner requires `--authorize-execution` and `EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true`, prepares the shared meteorology cache with downloads disabled, and asserts readiness before any HYSPLIT process starts.

The initial design uses two facilities and two release times:

```text
F001__20200501T000000Z, F001__20200501T060000Z,
F004__20200501T000000Z, F004__20200501T060000Z
```

All four May runs share `RP202005.gbl`. Each run has an isolated output directory and is executed, parsed, and receptor-extracted before the next run. Progress is persisted after every boundary in `controlled_multirun_ledger.csv` and `.rds`, so a failure does not erase successful results. Existing non-empty run directories are rejected unless the caller explicitly changes the runner policy.

After controlled execution, the ordinary targets pipeline discovers the completed metadata and parsed products. It does not execute HYSPLIT or download meteorology; a second run should be up to date. The summary script reports runtime, raw and filtered records, raster layers, receptor rows, intercepts, dyads, and failures.

The smoke test is intentionally sequential and limited to one meteorology month. HPC parallelism should be added only after the shared-cache lock and ledger semantics are exercised in this controlled path.

## Demonstration result

The controlled demonstration used four runs (`F001` and `F004` at 00:00 and 06:00 UTC). All four reused `RP202005.gbl`, completed HYSPLIT execution, parsing, and receptor extraction. Each produced 20,160 raw records and 119 receptor rows; within-20-km records were 3,292, 2,971, 8,471, and 12,550 respectively. The ordinary pipeline then completed with no failed targets, and the second invocation skipped all 40 targets. No meteorology download occurred during either controlled or ordinary execution.

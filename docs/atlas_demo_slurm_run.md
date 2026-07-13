# Atlas demonstration completion job

This bundle completes the seven remaining demonstration HYSPLIT runs in one
single-node SLURM allocation with two to four local workers. It then runs the
ordinary pipeline twice and verifies that all 12 runs are complete and the
`targets` store is fully up to date.

## Install the files

Copy the bundle contents into the repository root, preserving `hpc/`, `scripts/`,
and `docs/`.

```bash
chmod +x hpc/submit_atlas_demo_remaining.sh hpc/atlas_demo_remaining.sbatch
```

## Submit

```bash
./hpc/submit_atlas_demo_remaining.sh 4
```

Use `2`, `3`, or `4` workers. The helper requires exactly seven remaining
`planned` or `ready` runs and verifies cached meteorology without downloading.

## Monitor

```bash
squeue -u "$USER"
sacct -j JOB_ID --format=JobID,State,Elapsed,MaxRSS,AllocCPUS,ExitCode
tail -f local/facility_exchange_demo/logs/demo7_JOB_ID.out
```

## Expected result

- Seven runs execute.
- All 12 manifest runs end in `completed` state.
- No active execution locks remain.
- The first ordinary pipeline run ingests 12 completed branches.
- The second ordinary pipeline run is fully skipped/up to date.
- `verify_demo_pipeline_completion.R` reports `VERIFICATION PASSED`.

Status is written under `local/facility_exchange_demo/atlas_demo7/`.

This is a single-parent, local-worker job, not a SLURM array.

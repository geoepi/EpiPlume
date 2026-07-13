# Atlas single-node manifest execution

This wrapper uses one SLURM allocation and bounded local workers.

State handling:

- `planned`/`ready`: execute HYSPLIT.
- `execution_failed`: retry only with `ALLOW_RETRY_FAILED=true`.
- `parse_failed`/`receptor_failed`: resume postprocessing only.
- `completed`: skip.
- `meteorology_blocked`/`running`/`invalid`: stop for inspection.

Install:

```bash
chmod +x hpc/atlas_manifest_single_node.sbatch
chmod +x hpc/submit_atlas_manifest.sh
```

Submit with four workers:

```bash
./hpc/submit_atlas_manifest.sh 4
```

Retry reconciled execution failures:

```bash
ALLOW_RETRY_FAILED=true ./hpc/submit_atlas_manifest.sh 2
```

Successful terminal output:

```text
VERIFICATION_PASSED
completed_runs=12
active_locks=0
targets_outdated=0
```

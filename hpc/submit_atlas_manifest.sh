#!/bin/bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/project/hpai_plume/EpiPlume}"
WORKERS="${1:-4}"
ALLOW_RETRY_FAILED="${ALLOW_RETRY_FAILED:-false}"

cd "${REPO_DIR}"

CONFIG="config/facility_exchange_demo.yml"
MANIFEST="local/facility_exchange_demo/manifests/hysplit_run_manifest.csv"
STATE_DIR="local/facility_exchange_demo/atlas_slurm_state"
mkdir -p "${STATE_DIR}" local/facility_exchange_demo/logs

Rscript scripts/prepare_hysplit_manifest_meteorology.R --config "${CONFIG}" --manifest "${MANIFEST}" --no-download
Rscript scripts/prepare_manifest_slurm_state.R --config "${CONFIG}" --manifest "${MANIFEST}" --output-dir "${STATE_DIR}"

cat "${STATE_DIR}/state_summary.csv"

FAILED_IDS="$(cat "${STATE_DIR}/execution_failed_run_ids.txt")"
if [[ -n "${FAILED_IDS}" && "${ALLOW_RETRY_FAILED}" != "true" ]]; then
  echo "Execution-failed runs exist. Re-submit with:" >&2
  echo "ALLOW_RETRY_FAILED=true $0 ${WORKERS}" >&2
  exit 3
fi

SUBMISSION="$(sbatch --export=ALL,REPO_DIR="${REPO_DIR}",WORKERS="${WORKERS}",ALLOW_RETRY_FAILED="${ALLOW_RETRY_FAILED}" hpc/atlas_manifest_single_node.sbatch)"
echo "${SUBMISSION}"
JOB_ID="$(echo "${SUBMISSION}" | awk '{print $NF}')"
echo "${JOB_ID}" > "${STATE_DIR}/submitted_job_id.txt"

echo "Monitor with:"
echo "squeue -j ${JOB_ID}"
echo "sacct -j ${JOB_ID} --format=JobID,State,Elapsed,MaxRSS,AllocCPUS,ExitCode"
echo "tail -f local/facility_exchange_demo/logs/manifest_${JOB_ID}.out"

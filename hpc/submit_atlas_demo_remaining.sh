#!/bin/bash
set -euo pipefail
REPO_DIR="${REPO_DIR:-/project/hpai_plume/EpiPlume}"
WORKERS="${1:-4}"
if [[ "${WORKERS}" -lt 2 || "${WORKERS}" -gt 4 ]]; then echo "Usage: $0 [workers: 2-4]" >&2; exit 2; fi
cd "${REPO_DIR}"
CONFIG="config/facility_exchange_demo.yml"
MANIFEST="local/facility_exchange_demo/manifests/hysplit_run_manifest.csv"
LOG_DIR="local/facility_exchange_demo/logs"
STATUS_DIR="local/facility_exchange_demo/atlas_demo7"
for path in "${CONFIG}" "${MANIFEST}" "hpc/atlas_demo_remaining.sbatch"; do [[ -e "${path}" ]] || { echo "Required path is missing: ${path}" >&2; exit 3; }; done
command -v sbatch >/dev/null 2>&1 || { echo "sbatch is not available in PATH." >&2; exit 4; }
mkdir -p "${LOG_DIR}" "${STATUS_DIR}"
echo "Repository: ${REPO_DIR}"
echo "Commit: $(git rev-parse HEAD)"
echo "Workers: ${WORKERS}"
RUN_IDS="$(Rscript scripts/select_remaining_demo_runs.R --config "${CONFIG}" --manifest "${MANIFEST}" --expected-remaining 7)"
echo "Remaining run IDs:"
echo "${RUN_IDS}" | tr ',' '\n'
Rscript scripts/prepare_hysplit_manifest_meteorology.R --config "${CONFIG}" --manifest "${MANIFEST}" --run-ids "${RUN_IDS}" --no-download
SUBMISSION="$(sbatch --export=ALL,REPO_DIR="${REPO_DIR}",RUN_WORKERS="${WORKERS}",EXPECTED_REMAINING=7 hpc/atlas_demo_remaining.sbatch)"
echo "${SUBMISSION}"
JOB_ID="$(echo "${SUBMISSION}" | awk '{print $NF}')"
echo "${JOB_ID}" > "${STATUS_DIR}/submitted_job_id.txt"
echo "Monitor with:"
echo "  squeue -j ${JOB_ID}"
echo "  sacct -j ${JOB_ID} --format=JobID,State,Elapsed,MaxRSS,AllocCPUS,ExitCode"
echo "  tail -f ${LOG_DIR}/demo7_${JOB_ID}.out"

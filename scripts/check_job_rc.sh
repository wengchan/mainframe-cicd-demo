#!/usr/bin/env bash
# check_job_rc.sh — poll TK4- printer spool until job output appears,
# then check MAXCC via mvs_submit.py checkrc.
# Exit 0 = success, Exit 1 = failure.
#
# Usage: check_job_rc.sh <container_name> <jobname>

set -euo pipefail

CONTAINER="$1"
JOB_NAME="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MAX_POLLS=20
POLL_INTERVAL=15

echo ">>> Polling TK4- spool for job: ${JOB_NAME}"
echo ">>> Container: ${CONTAINER} | Max: ${MAX_POLLS} x ${POLL_INTERVAL}s"

# ------------------------------------------------------------------
# Poll until job output appears in the printer files
# ------------------------------------------------------------------
attempt=0
job_found=0

while [ $attempt -lt $MAX_POLLS ]; do
    attempt=$(( attempt + 1 ))
    echo -n ">>> Poll ${attempt}/${MAX_POLLS} ... "

    if python3 "$SCRIPT_DIR/mvs_submit.py" getlog \
           "$CONTAINER" "$JOB_NAME" "/tmp/${JOB_NAME}_poll.txt" 2>/dev/null; then
        echo "found."
        job_found=1
        break
    fi

    echo "not yet — waiting ${POLL_INTERVAL}s..."
    sleep "$POLL_INTERVAL"
done

if [ $job_found -eq 0 ]; then
    echo "ERROR: ${JOB_NAME} output not found after $(( MAX_POLLS * POLL_INTERVAL ))s."
    echo "       Verify TK4- booted fully and JOBNAME in JCL matches ${JOB_NAME}."
    exit 1
fi

# ------------------------------------------------------------------
# Show output and check MAXCC / ABEND
# ------------------------------------------------------------------
echo ">>> Job output:"
echo "------------------------------------------------------------"
cat "/tmp/${JOB_NAME}_poll.txt"
echo "------------------------------------------------------------"

python3 "$SCRIPT_DIR/mvs_submit.py" checkrc "$CONTAINER" "$JOB_NAME"

#!/bin/bash
#
# Quick script to tail the latest SOL log file
#

LOG_DIR="./logs"

# Check if logs directory exists
if [ ! -d "${LOG_DIR}" ]; then
    echo "No logs directory found. Run monitor-sol.sh first."
    exit 1
fi

# Find the latest log file
LATEST_LOG=$(ls -t "${LOG_DIR}"/sol-output-*.log 2>/dev/null | head -1)

if [ -z "${LATEST_LOG}" ]; then
    echo "No SOL log files found in ${LOG_DIR}"
    exit 1
fi

echo "Tailing: ${LATEST_LOG}"
echo "Press CTRL+C to stop"
echo ""

tail -f "${LATEST_LOG}"


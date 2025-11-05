#!/bin/bash
#
# IPMI SOL Monitor Script
# Captures Serial Over LAN output to a log file for debugging deployments
#

# Get the repo root directory (parent of tools/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables from .env file in repo root
if [ ! -f "${REPO_ROOT}/.env" ]; then
    echo "ERROR: .env file not found!"
    echo ""
    echo "Please create a .env file in the repo root with your IPMI credentials:"
    echo "  cp .env.example .env"
    echo "  # Then edit .env with your credentials"
    exit 1
fi

# Source the .env file
set -a
source "${REPO_ROOT}/.env"
set +a

# Validate required variables
if [ -z "${IPMI_HOST}" ] || [ -z "${IPMI_USER}" ] || [ -z "${IPMI_PASS}" ]; then
    echo "ERROR: Missing required environment variables in .env"
    echo "Required: IPMI_HOST, IPMI_USER, IPMI_PASS"
    exit 1
fi

# Log file location (in repo root)
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/sol-output-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

echo -e "${GREEN}=== IPMI SOL Monitor ===${NC}"
echo -e "IPMI Host: ${IPMI_HOST}"
echo -e "Log file:  ${LOG_FILE}"
echo ""

# Check if ipmitool is installed
if ! command -v ipmitool &> /dev/null; then
    echo -e "${RED}ERROR: ipmitool is not installed${NC}"
    echo ""
    echo "Install it with:"
    echo "  macOS:  brew install ipmitool"
    echo "  Ubuntu: sudo apt-get install ipmitool"
    echo "  CentOS: sudo yum install ipmitool"
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Deactivating SOL...${NC}"
    ipmitool -I lanplus -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol deactivate 2>/dev/null
    echo -e "${GREEN}Done. Log saved to: ${LOG_FILE}${NC}"
    exit 0
}

# Trap CTRL+C and cleanup
trap cleanup INT TERM

echo -e "${YELLOW}Deactivating any existing SOL sessions...${NC}"
ipmitool -I lanplus -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol deactivate 2>/dev/null
sleep 1

echo -e "${GREEN}Activating SOL and logging to file...${NC}"
echo -e "${YELLOW}Press CTRL+C to stop monitoring${NC}"
echo -e "${YELLOW}SOL will auto-reconnect if detached (10 second delay)${NC}"
echo ""
echo -e "${YELLOW}Tip: In another terminal, run:${NC}"
echo -e "  tail -f ${LOG_FILE}"
echo ""

# Auto-restart loop
while true; do
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Connecting to SOL...${NC}" | tee -a "${LOG_FILE}"
    
    # Activate SOL and write to log file
    ipmitool -I lanplus -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol activate | tee -a "${LOG_FILE}"
    
    # SOL disconnected (session ended)
    EXIT_CODE=$?
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] SOL disconnected (exit code: ${EXIT_CODE})${NC}" | tee -a "${LOG_FILE}"
    
    # Check if it was intentional exit (CTRL+C would have triggered cleanup trap)
    # If we get here, it was a disconnect, not user interruption
    echo -e "${YELLOW}Waiting 5 seconds before reconnecting...${NC}"
    sleep 5
    
    # Deactivate any stale sessions before reconnecting
    ipmitool -I lanplus -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol deactivate 2>/dev/null
    sleep 1
done

# Cleanup on normal exit (never reached due to loop, only via trap)
cleanup


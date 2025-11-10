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

# IPMI interface and security settings (override with env vars if needed)
SOL_INTERFACE="${SOL_INTERFACE:-lanplus}"             # lanplus (IPMI 2.0) or lan (IPMI 1.5)
IPMI_CIPHER_SUITE="${IPMI_CIPHER_SUITE:-3}"           # Cipher suite for lanplus (3 is most compatible)
IPMI_CIPHER_LIST="${IPMI_CIPHER_LIST:-3 17 12 8 0}"   # Fallback probe order
IPMI_PRIVILEGE_LEVEL="${IPMI_PRIVILEGE_LEVEL:-ADMINISTRATOR}"
SOL_RETRY_DELAY="${SOL_RETRY_DELAY:-5}"               # Seconds to wait before reconnecting

# Serial port settings (defaults match ttyS1 @ 115200)
SOL_COM_PORT="${SOL_COM_PORT:-1}"     # 0 = ttyS0 / COM1, 1 = ttyS1 / COM2
SOL_BAUD_RATE="${SOL_BAUD_RATE:-115200}"

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
echo -e "Serial:    ttyS${SOL_COM_PORT} @ ${SOL_BAUD_RATE}"
echo -e "Interface: ${SOL_INTERFACE}  Cipher: ${IPMI_CIPHER_SUITE}  Privilege: ${IPMI_PRIVILEGE_LEVEL}"
echo -e "Auto-reconnect: Enabled (${SOL_RETRY_DELAY}s delay)"
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
ipmitool -I "${SOL_INTERFACE}" -C "${IPMI_CIPHER_SUITE}" -L "${IPMI_PRIVILEGE_LEVEL}" \
  -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol deactivate 2>/dev/null
sleep 1

# Probe cipher suites if lanplus negotiation fails
if [ "${SOL_INTERFACE}" = "lanplus" ]; then
  if ! ipmitool -I lanplus -C "${IPMI_CIPHER_SUITE}" -L "${IPMI_PRIVILEGE_LEVEL}" -N 3 -R 1 \
        -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" mc info >/dev/null 2>&1; then
    echo -e "${YELLOW}Current cipher ${IPMI_CIPHER_SUITE} failed. Probing alternative cipher suites...${NC}"
    for c in ${IPMI_CIPHER_LIST}; do
      if ipmitool -I lanplus -C "$c" -L "${IPMI_PRIVILEGE_LEVEL}" -N 3 -R 1 \
           -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" mc info >/dev/null 2>&1; then
        IPMI_CIPHER_SUITE="$c"
        echo -e "${GREEN}Selected working cipher suite: ${IPMI_CIPHER_SUITE}${NC}"
        break
      fi
    done
  fi
fi

echo -e "${YELLOW}Configuring SOL parameters...${NC}"
ipmitool -I "${SOL_INTERFACE}" -C "${IPMI_CIPHER_SUITE}" -L "${IPMI_PRIVILEGE_LEVEL}" \
  -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol set baud "${SOL_BAUD_RATE}" >/dev/null 2>&1 || \
    echo -e "${RED}Warning: Unable to set SOL baud rate${NC}"
ipmitool -I "${SOL_INTERFACE}" -C "${IPMI_CIPHER_SUITE}" -L "${IPMI_PRIVILEGE_LEVEL}" \
  -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol set comport "${SOL_COM_PORT}" >/dev/null 2>&1 || \
    echo -e "${RED}Warning: Unable to set SOL COM port${NC}"

echo -e "${GREEN}Activating SOL and logging to file...${NC}"
echo -e "${YELLOW}Press CTRL+C to stop monitoring${NC}"
echo ""
echo -e "${YELLOW}Tip: In another terminal, run:${NC}"
echo -e "  tail -f ${LOG_FILE}"
echo ""

# Connection loop - automatically reconnect if SOL session drops
CONNECTION_COUNT=0
while true; do
    CONNECTION_COUNT=$((CONNECTION_COUNT + 1))
    
    if [ $CONNECTION_COUNT -gt 1 ]; then
        echo "" | tee -a "${LOG_FILE}"
        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] SOL session ended. Reconnecting in ${SOL_RETRY_DELAY}s... (attempt #${CONNECTION_COUNT})${NC}" | tee -a "${LOG_FILE}"
        echo "" | tee -a "${LOG_FILE}"
        sleep "${SOL_RETRY_DELAY}"
        
        # Deactivate any stale sessions before reconnecting
        ipmitool -I "${SOL_INTERFACE}" -C "${IPMI_CIPHER_SUITE}" -L "${IPMI_PRIVILEGE_LEVEL}" \
          -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol deactivate 2>/dev/null
        sleep 1
    fi
    
    # Activate SOL and write to log file
    # Also display to console
    ipmitool -I "${SOL_INTERFACE}" -C "${IPMI_CIPHER_SUITE}" -L "${IPMI_PRIVILEGE_LEVEL}" \
      -H "${IPMI_HOST}" -U "${IPMI_USER}" -P "${IPMI_PASS}" sol activate 2>&1 | tee -a "${LOG_FILE}"
    
    # Check exit status
    EXIT_CODE=$?
    
    # If we get here, SOL session ended
    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] SOL activation failed with exit code: ${EXIT_CODE}${NC}" | tee -a "${LOG_FILE}"
    fi
    
    # Continue loop to reconnect (unless interrupted by CTRL+C via trap)
done

# Cleanup on normal exit (only reached via CTRL+C trap)
cleanup


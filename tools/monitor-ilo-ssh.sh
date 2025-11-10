#!/bin/bash
#
# HP iLO SSH Console Monitor
# Alternative to IPMI SOL for HP servers where IPMI is disabled
#

# Get the repo root directory (parent of tools/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables from .env file in repo root
if [ ! -f "${REPO_ROOT}/.env" ]; then
    echo "ERROR: .env file not found!"
    echo ""
    echo "Please create a .env file in the repo root with your iLO credentials:"
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
LOG_FILE="${LOG_DIR}/ilo-console-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

echo -e "${GREEN}=== HP iLO SSH Console Monitor ===${NC}"
echo -e "iLO Host: ${IPMI_HOST}"
echo -e "Log file: ${LOG_FILE}"
echo ""

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}Installing sshpass for automated SSH login...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "On macOS, install with: brew install hudochenkov/sshpass/sshpass"
        echo ""
        echo "Or use the expect-based method below..."
    else
        echo "On Linux, install with: sudo apt-get install sshpass"
    fi
    echo ""
fi

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${GREEN}Done. Log saved to: ${LOG_FILE}${NC}"
    exit 0
}

# Trap CTRL+C and cleanup
trap cleanup INT TERM

echo -e "${GREEN}Connecting to iLO SSH console...${NC}"
echo -e "${YELLOW}Press CTRL+C to stop monitoring${NC}"
echo ""
echo -e "${YELLOW}Tip: In another terminal, run:${NC}"
echo -e "  tail -f ${LOG_FILE}"
echo ""

# Use expect to automate the SSH login and start VSP (Virtual Serial Port)
expect -c "
set timeout 10
log_file -a \"${LOG_FILE}\"

# Connect with legacy crypto for old iLO
spawn ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
          -o HostKeyAlgorithms=+ssh-rsa,ssh-dss \
          -o PubkeyAcceptedKeyTypes=+ssh-rsa \
          -o Ciphers=+aes128-cbc,aes256-cbc \
          ${IPMI_USER}@${IPMI_HOST}

expect {
    \"password:\" {
        send \"${IPMI_PASS}\r\"
        exp_continue
    }
    \"hpiLO->\" {
        # We're logged in, start the virtual serial port
        send \"vsp\r\"
        # Now just interact - user can type commands, see output
        interact
    }
    timeout {
        puts \"Connection timeout\"
        exit 1
    }
    eof {
        puts \"Connection closed\"
        exit 0
    }
}
" | tee -a "${LOG_FILE}"

cleanup


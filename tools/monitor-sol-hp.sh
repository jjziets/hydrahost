#!/bin/bash
#
# HP iLO SOL Monitor Script
# For HP ProLiant servers with iLO
# Uses SSH to iLO for more reliable serial console access
#
# Usage: ./monitor-sol-hp.sh
#

# Get the repo root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables
if [ ! -f "${REPO_ROOT}/.env" ]; then
    echo "ERROR: .env file not found!"
    echo "Please create .env with: IPMI_HOST, IPMI_USER, IPMI_PASS"
    exit 1
fi

source "${REPO_ROOT}/.env"

# Validate
if [ -z "${IPMI_HOST}" ] || [ -z "${IPMI_USER}" ] || [ -z "${IPMI_PASS}" ]; then
    echo "ERROR: Missing IPMI credentials in .env"
    exit 1
fi

# Log file
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/sol-output-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== HP iLO SOL Monitor ===${NC}"
echo -e "iLO Host: ${IPMI_HOST}"
echo -e "Log file: ${LOG_FILE}"
echo ""
echo -e "${YELLOW}Connecting via SSH to iLO...${NC}"
echo -e "${YELLOW}Press ESC then ( to exit${NC}"
echo ""

# Function to cleanup
cleanup() {
    echo ""
    echo -e "${GREEN}Log saved to: ${LOG_FILE}${NC}"
    exit 0
}

trap cleanup INT TERM

# Use sshpass if available, otherwise use expect-style here-doc
if command -v sshpass &> /dev/null; then
    # Using sshpass (simpler)
    # Add legacy crypto support for old iLO versions
    sshpass -p "${IPMI_PASS}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
        -o HostKeyAlgorithms=+ssh-rsa,ssh-dss \
        -o PubkeyAcceptedKeyTypes=+ssh-rsa,ssh-dss \
        "${IPMI_USER}@${IPMI_HOST}" \
        "vsp" 2>&1 | tee -a "${LOG_FILE}"
else
    # Using expect-style with SSH
    # HP iLO SSH requires "vsp" command to start virtual serial port
    cat > /tmp/ilo-sol-$$.exp << EOFEXP
#!/usr/bin/expect -f
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${IPMI_USER}@${IPMI_HOST}
expect {
    "password:" {
        send "${IPMI_PASS}\r"
        exp_continue
    }
    "hpiLO->" {
        send "vsp\r"
        interact
    }
    timeout {
        puts "Connection timeout"
        exit 1
    }
}
EOFEXP
    
    chmod +x /tmp/ilo-sol-$$.exp
    /tmp/ilo-sol-$$.exp | tee -a "${LOG_FILE}"
    rm -f /tmp/ilo-sol-$$.exp
fi

cleanup


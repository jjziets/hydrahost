#!/bin/bash
#
# Network Diagnostics for iPXE Provisioning
# Tests connectivity to GitHub and validates iPXE boot files
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/jjziets/hydrahost/main"

echo -e "${GREEN}=== iPXE Provisioning Network Diagnostics ===${NC}"
echo ""

# Test 1: DNS Resolution
echo -e "${YELLOW}[1/6] Testing DNS resolution...${NC}"
if host raw.githubusercontent.com > /dev/null 2>&1; then
    IP=$(host raw.githubusercontent.com | grep "has address" | head -1 | awk '{print $4}')
    echo -e "${GREEN}✓ DNS OK - raw.githubusercontent.com resolves to ${IP}${NC}"
else
    echo -e "${RED}✗ DNS FAILED - Cannot resolve raw.githubusercontent.com${NC}"
fi
echo ""

# Test 2: Network Connectivity
echo -e "${YELLOW}[2/6] Testing network connectivity to GitHub...${NC}"
if ping -c 2 raw.githubusercontent.com > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ping OK${NC}"
else
    echo -e "${RED}✗ Ping FAILED - Network may be blocking ICMP${NC}"
fi
echo ""

# Test 3: HTTPS Connectivity
echo -e "${YELLOW}[3/6] Testing HTTPS connectivity...${NC}"
if timeout 5 bash -c "echo > /dev/tcp/raw.githubusercontent.com/443" 2>/dev/null; then
    echo -e "${GREEN}✓ HTTPS port 443 is reachable${NC}"
else
    echo -e "${RED}✗ HTTPS port 443 is NOT reachable - Firewall blocking?${NC}"
fi
echo ""

# Test 4: boot.ipxe accessibility
echo -e "${YELLOW}[4/6] Testing boot.ipxe file...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${REPO_URL}/boot.ipxe")
if [ "$HTTP_CODE" = "200" ]; then
    SIZE=$(curl -sI "${REPO_URL}/boot.ipxe" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    echo -e "${GREEN}✓ boot.ipxe accessible (HTTP $HTTP_CODE, ${SIZE} bytes)${NC}"
    echo ""
    echo "First few lines:"
    curl -s "${REPO_URL}/boot.ipxe" | head -10
else
    echo -e "${RED}✗ boot.ipxe NOT accessible (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Test 5: Kernel and initrd files
echo -e "${YELLOW}[5/6] Testing kernel/initrd files...${NC}"

# Check vmlinuz
VMLINUZ_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${REPO_URL}/casper/vmlinuz")
if [ "$VMLINUZ_CODE" = "200" ]; then
    echo -e "${GREEN}✓ vmlinuz accessible (HTTP $VMLINUZ_CODE)${NC}"
else
    echo -e "${RED}✗ vmlinuz NOT accessible (HTTP $VMLINUZ_CODE)${NC}"
fi

# Check initrd
INITRD_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${REPO_URL}/casper/initrd")
if [ "$INITRD_CODE" = "200" ]; then
    echo -e "${GREEN}✓ initrd accessible (HTTP $INITRD_CODE)${NC}"
else
    echo -e "${RED}✗ initrd NOT accessible (HTTP $INITRD_CODE)${NC}"
fi
echo ""

# Test 6: Autoinstall files
echo -e "${YELLOW}[6/6] Testing autoinstall configuration...${NC}"

USER_DATA_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${REPO_URL}/autoinstall/user-data")
if [ "$USER_DATA_CODE" = "200" ]; then
    echo -e "${GREEN}✓ user-data accessible (HTTP $USER_DATA_CODE)${NC}"
else
    echo -e "${RED}✗ user-data NOT accessible (HTTP $USER_DATA_CODE)${NC}"
fi

META_DATA_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${REPO_URL}/autoinstall/meta-data")
if [ "$META_DATA_CODE" = "200" ]; then
    echo -e "${GREEN}✓ meta-data accessible (HTTP $META_DATA_CODE)${NC}"
else
    echo -e "${RED}✗ meta-data NOT accessible (HTTP $META_DATA_CODE)${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}=== Diagnostics Complete ===${NC}"
echo ""
echo "If all tests pass, the issue is likely on the provisioning bridge/network."
echo "Check:"
echo "  - Firewall rules on the provisioning bridge"
echo "  - NAT/routing configuration"
echo "  - DNS server configuration for the provisioning network"
echo ""


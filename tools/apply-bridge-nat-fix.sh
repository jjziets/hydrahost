#!/bin/bash
#
# Apply NAT fix for provisioning network internet access
# Run this on each bridge server to enable custom iPXE boot
#
# Usage: sudo ./apply-bridge-nat-fix.sh
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROV_NETWORK="10.230.12.0/24"
INTERNET_IFACE="eno8"

echo -e "${GREEN}=== Bridge NAT Fix for Custom iPXE Boot ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if IP forwarding is enabled
echo -e "${YELLOW}[1/5] Checking IP forwarding...${NC}"
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo -e "${GREEN}✓ IP forwarding is enabled${NC}"
else
    echo -e "${YELLOW}⚠ IP forwarding is disabled, enabling...${NC}"
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo -e "${GREEN}✓ IP forwarding enabled${NC}"
fi
echo ""

# Check if NAT rule already exists
echo -e "${YELLOW}[2/5] Checking existing NAT rules...${NC}"
if iptables -t nat -C POSTROUTING -s "$PROV_NETWORK" -o "$INTERNET_IFACE" -j MASQUERADE 2>/dev/null; then
    echo -e "${YELLOW}⚠ NAT rule already exists${NC}"
    RULE_EXISTS=true
else
    echo -e "${GREEN}✓ No conflicting rules found${NC}"
    RULE_EXISTS=false
fi
echo ""

# Add NAT rule
echo -e "${YELLOW}[3/5] Adding NAT rule...${NC}"
if [ "$RULE_EXISTS" = false ]; then
    iptables -t nat -A POSTROUTING -s "$PROV_NETWORK" -o "$INTERNET_IFACE" -j MASQUERADE
    echo -e "${GREEN}✓ NAT rule added${NC}"
else
    echo -e "${YELLOW}⚠ Skipping (already exists)${NC}"
fi
echo ""

# Make persistent
echo -e "${YELLOW}[4/5] Making NAT rule persistent...${NC}"

# Check if netfilter-persistent is available
if command -v netfilter-persistent &> /dev/null; then
    echo "Using netfilter-persistent..."
    netfilter-persistent save
    echo -e "${GREEN}✓ Rules saved with netfilter-persistent${NC}"
elif [ -d "/etc/iptables" ]; then
    echo "Using iptables-save..."
    iptables-save > /etc/iptables/rules.v4
    echo -e "${GREEN}✓ Rules saved to /etc/iptables/rules.v4${NC}"
else
    # Create systemd service as fallback
    echo "Creating systemd service..."
    cat > /etc/systemd/system/provisioning-nat.service <<EOF
[Unit]
Description=Enable NAT for provisioning network
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s ${PROV_NETWORK} -o ${INTERNET_IFACE} -j MASQUERADE
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable provisioning-nat.service
    echo -e "${GREEN}✓ Systemd service created and enabled${NC}"
fi
echo ""

# Verify
echo -e "${YELLOW}[5/5] Verifying configuration...${NC}"
echo ""
echo "IP Forwarding:"
cat /proc/sys/net/ipv4/ip_forward
echo ""
echo "NAT Rules for provisioning network:"
iptables -t nat -L POSTROUTING -v -n | grep "$PROV_NETWORK" || echo "No rules found!"
echo ""

echo -e "${GREEN}=== Fix Applied Successfully ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Test from an iPXE client on the provisioning network"
echo "  2. Verify clients can reach the internet"
echo "  3. Try chainloading a custom iPXE script"
echo ""
echo "To test manually:"
echo "  - In iPXE shell: dhcp"
echo "  - In iPXE shell: ping 8.8.8.8"
echo "  - In iPXE shell: chain https://raw.githubusercontent.com/jjziets/hydrahost/main/boot.ipxe"
echo ""


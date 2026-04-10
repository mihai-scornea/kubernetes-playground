#!/bin/bash -e

#!bash

# Ensure this script is run on k8s-worker-1
EXPECTED_HOSTNAME="k8s-worker-1"
CURRENT_HOSTNAME="$(hostname -s)"

if [ "$CURRENT_HOSTNAME" != "$EXPECTED_HOSTNAME" ]; then
    echo "Error: This script must be run on $EXPECTED_HOSTNAME, but current host is $CURRENT_HOSTNAME"
    exit 1
fi

NS1="NS1"
NS2="NS2"

BRIDGE_NAME="br0"

TO_BRIDGE_SUBNET="10.2.0.0/24"
TO_NODE_IP="192.168.50.12"

# Tunnel IPs and ports
TUNNEL_IP="172.31.255.1"
TUNNEL_PORT="9000"
TO_TUNNEL_IP="172.31.255.2"
TO_TUNNEL_PORT="9000"

echo "Current network state before cleanup:"
ip a || true
ip route || true
echo "Network namespaces before cleanup:"
ip netns list || true
echo "Network interfaces before cleanup:"
ip link show type veth || true
echo "Bridge interfaces before cleanup:"
ip link show type bridge || true
echo "Tunnel interfaces before cleanup:"
ip link show tundudp 2>/dev/null || true

echo "Starting cleanup on this node..."

echo "Stopping tunnel (socat)..."
pkill -f "socat.*$TO_NODE_IP:$TO_TUNNEL_PORT" 2>/dev/null || true

echo "Removing tunnel routes..."
sudo ip route del $TO_BRIDGE_SUBNET via $TO_TUNNEL_IP dev tundudp 2>/dev/null || true
sudo ip route del $TO_TUNNEL_IP dev tundudp 2>/dev/null || true

echo "Deleting tunnel interface..."
sudo ip link set tundudp down 2>/dev/null || true
sudo ip link del tundudp 2>/dev/null || true

# Remove route to other node
echo "Removing route to other node..."
sudo ip route del $TO_BRIDGE_SUBNET via $TO_NODE_IP dev enp0s8 2>/dev/null || true

# Delete namespaces (this also deletes veth10 and veth20)
echo "Deleting namespaces..."
sudo ip netns del $NS1 2>/dev/null || true
sudo ip netns del $NS2 2>/dev/null || true

# Delete bridge (this detaches veth11 and veth21)
echo "Deleting bridge..."
sudo ip link set $BRIDGE_NAME down 2>/dev/null || true
sudo ip link del $BRIDGE_NAME 2>/dev/null || true

# Delete remaining veth interfaces (host side)
echo "Deleting remaining veth interfaces..."
sudo ip link del veth11 2>/dev/null || true
sudo ip link del veth21 2>/dev/null || true

# Reset sysctl values (optional but clean)
echo "Resetting sysctl settings..."
sudo sysctl -w net.ipv4.ip_forward=0
sudo sysctl -w net.ipv4.conf.all.rp_filter=1
sudo sysctl -w net.ipv4.conf.default.rp_filter=1

echo "Network state after cleanup:"
ip a || true
ip route || true
echo "Network namespaces after cleanup:"
ip netns list || true
echo "Network interfaces after cleanup:"
ip link show type veth || true
echo "Bridge interfaces after cleanup:"
ip link show type bridge || true
echo "Tunnel interfaces after cleanup:"
ip link show tundudp 2>/dev/null || true

echo "Cleanup complete."
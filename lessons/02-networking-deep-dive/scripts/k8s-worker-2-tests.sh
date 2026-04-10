#!/bin/bash

#!bash

# Ensure this script is run on k8s-worker-2
EXPECTED_HOSTNAME="k8s-worker-2"
CURRENT_HOSTNAME="$(hostname -s)"

if [ "$CURRENT_HOSTNAME" != "$EXPECTED_HOSTNAME" ]; then
    echo "Error: This script must be run on $EXPECTED_HOSTNAME, but current host is $CURRENT_HOSTNAME"
    exit 1
fi

# We will first define some variables that we will use throughout the script.

# The names of our namespaces.
# We will create two namespaces to simulate two different containers.
NS1="NS1"
NS2="NS2"

# The IP of the node we are on (should be the IP of k8s-worker-2)
NODE_IP="192.168.50.12"

# The subnet and IP of the bridge we will create.
# The bridge itself acts as a virtual switch (L2),
# while the host uses it as a gateway (L3, router behavior) for routing traffic.
BRIDGE_SUBNET="10.2.0.0/24"
BRIDGE_IP="10.2.0.1"

# The IPs we will assign to the two network namespaces
# Note that they are on the same subnet as the bridge.
# They will communicate with each other through the bridge.
# They will also communicate with the host machine
# (and the outside world) through the bridge.
IP1="10.2.0.2"
IP2="10.2.0.3"

# The IP address of the other node (k8s-worker-1) that we will use to test connectivity.
TO_NODE_IP="192.168.50.11"

# The subnet and IP of the bridge we will create on the other node.
TO_BRIDGE_SUBNET="10.1.0.0/24"
TO_BRIDGE_IP="10.1.0.1"

# The IP addresses of the namespaces on the other node.
TO_IP1="10.1.0.2"
TO_IP2="10.1.0.3"

# We will now test connectivity between the namespaces on this node.

# ping adaptor attached to NS1 from NS1
echo ""
echo "Testing connectivity from $NS1 to its own veth interface..."
sudo ip netns exec $NS1 ping -c 3 $IP1

# ping localhost from NS1
echo ""
echo "Testing connectivity from $NS1 to localhost..."
sudo ip netns exec $NS1 ping -c 3 127.0.0.1

# ping adaptor attached to NS2 from NS2
echo ""
echo "Testing connectivity from $NS2 to its own veth interface..."
sudo ip netns exec $NS2 ping -c 3 $IP2

# ping localhost from NS2
echo ""
echo "Testing connectivity from $NS2 to localhost..."
sudo ip netns exec $NS2 ping -c 3 127.0.0.1

# ping NS2 from NS1
echo ""
echo "Testing connectivity from $NS1 to $NS2..."
sudo ip netns exec $NS1 ping -c 3 $IP2

# ping NS1 from NS2
echo ""
echo "Testing connectivity from $NS2 to $NS1..."
sudo ip netns exec $NS2 ping -c 3 $IP1

# ping the bridge from NS1
echo ""
echo "Testing connectivity from $NS1 to the bridge..."
sudo ip netns exec $NS1 ping -c 3 $BRIDGE_IP

# ping the bridge from NS2
echo ""
echo "Testing connectivity from $NS2 to the bridge..."
sudo ip netns exec $NS2 ping -c 3 $BRIDGE_IP

# ping the host machine from NS1
echo ""
echo "Testing connectivity from $NS1 to the host machine..."
sudo ip netns exec $NS1 ping -c 3 $NODE_IP

# ping the host machine from NS2
echo ""
echo "Testing connectivity from $NS2 to the host machine..."
sudo ip netns exec $NS2 ping -c 3 $NODE_IP

# ping the other node from NS1
echo ""
echo "Testing connectivity from $NS1 to the other node..."
sudo ip netns exec $NS1 ping -c 3 $TO_NODE_IP

# ping the other node from NS2
echo ""
echo "Testing connectivity from $NS2 to the other node..."
sudo ip netns exec $NS2 ping -c 3 $TO_NODE_IP

# ping the namespaces on the other node from NS1
echo ""
echo "Testing connectivity from $NS1 to namespaces on the other node..."
sudo ip netns exec $NS1 ping -c 3 $TO_IP1
sudo ip netns exec $NS1 ping -c 3 $TO_IP2

# ping the namespaces on the other node from NS2
echo ""
echo "Testing connectivity from $NS2 to namespaces on the other node..."
sudo ip netns exec $NS2 ping -c 3 $TO_IP1
sudo ip netns exec $NS2 ping -c 3 $TO_IP2

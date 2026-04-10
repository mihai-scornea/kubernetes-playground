#!/bin/bash -e

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

# Tunnel IPs and ports
TUNNEL_IP="172.31.255.2"
TUNNEL_PORT="9000"
TO_TUNNEL_IP="172.31.255.1"
TO_TUNNEL_PORT="9000"

# Enable IP forwarding so the host can route traffic between interfaces
# (i.e. act as a router for the namespaces).
# Disable reverse path filtering (rp_filter), which may drop packets if they
# enter and leave through different interfaces (common in routed setups like this).
echo "Enabling IP forwarding and adjusting rp_filter..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.default.rp_filter=0

# Creating the namespaces on this node
echo "Creating namespaces $NS1 and $NS2..."
sudo ip netns add $NS1
sudo ip netns add $NS2

# To view the namespaces we created, we can run:
ip netns list

# Creating the veth pairs. These are virtual Ethernet interfaces that
# will connect the namespaces to the bridge. Think of them as virtual cables.
# Such virtual cables have an interesting feature: Their ends can be turned on and off
# Think of it as if the plugs of the cables have a switch that can turn traffic on and off.
echo "Creating veth pairs..."
sudo ip link add veth10 type veth peer name veth11
sudo ip link add veth20 type veth peer name veth21

# To view the veth pairs we created, we can run:
ip link show type veth

# Now we will add the veth interfaces to the namespaces.
# This is like plugging the virtual cables into the namespaces.
# The veth interfaces will allow the namespaces to communicate with each other
echo "Adding veth interfaces to namespaces..."
sudo ip link set veth10 netns $NS1
sudo ip link set veth20 netns $NS2

# We will now enable the veth interfaces inside the namespaces.
# This is like turning on the ends of the virtual cables so that they can start transmitting data.
# Our virtual cables have such switches on their plugs that can turn them on and off :)
# The "ip netns exec $NS1" command allows us to run commands inside the namespace $NS1
# as if we were in a separate machine inside that namespace. The same applies to $NS2.
echo "Enabling veth interfaces..."
sudo ip netns exec $NS1 ip link set veth10 up
sudo ip netns exec $NS2 ip link set veth20 up


# We will now create a bridge on the host machine.
# This bridge will act as a virtual switch.
echo "Creating bridge br0..."
sudo ip link add name br0 type bridge

## To view the bridge we created, we can run:
ip link show type bridge

# We will add the other ends of the veth pairs to the bridge.
# This is like plugging the other ends of the virtual cables into the bridge.
echo "Adding veth interfaces to bridge..."
sudo ip link set veth11 master br0
sudo ip link set veth21 master br0

# We will now assign IP addresses to the veth interfaces inside the namespaces.
# This is like configuring the network settings on the machines inside the namespaces.
echo "Assigning IP addresses to veth interfaces in namespaces..."
sudo ip netns exec $NS1 ip addr add $IP1/24 dev veth10
sudo ip netns exec $NS2 ip addr add $IP2/24 dev veth20

# We will also assign an IP address to the bridge on the host machine.
# This is like configuring the network settings on the virtual switch.
# This IP is not needed for communication between namespaces on the same host (L2),
# but it acts as the default gateway for traffic leaving the subnet (L3 routing).

echo "Assigning IP address to bridge on host..."
sudo ip addr add $BRIDGE_IP/24 dev br0

# We will now enable the bridge on the host machine.
# This is like turning on the virtual switch so that it can start forwarding traffic.
echo "Enabling bridge..."
sudo ip link set dev br0 up

# We will now enable the veth interfaces connected to the bridge.
# This is like turning on the cable ends connected to the switch.
echo "Enabling veth interfaces connected to the bridge..."
sudo ip link set veth11 up
sudo ip link set veth21 up

# We will now set the loopback interface inside the namespaces to up.
# This lets the containers use 127.0.0.1 or localhost to communicate with themselves.
echo "Enabling loopback interfaces in namespaces..."
sudo ip netns exec $NS1 ip link set lo up
sudo ip netns exec $NS2 ip link set lo up

# To view the network configuration inside the namespaces, we can run:
echo "Network configuration in $NS1:"
sudo ip netns exec $NS1 ip a
echo "Network configuration in $NS2:"
sudo ip netns exec $NS2 ip a

# At this point:
# - The bridge can switch traffic between namespaces on the same host (L2).
# - But namespaces do not yet know how to reach other networks.
# We will now configure a default gateway.

# We will now set the default route inside the namespaces to point to the bridge IP.
# This is like configuring the default gateway on the machines inside the namespaces.
# This allows the namespaces to communicate with the outside world through the bridge.
# When the bridge receives traffic from the namespaces that is not meant for the other
# namespace in the same machine, it will forward it to the host machine, which will
# then forward it to the outside world.
echo "Setting default route in namespaces..."
sudo ip netns exec $NS1 ip route add default via $BRIDGE_IP dev veth10
sudo ip netns exec $NS2 ip route add default via $BRIDGE_IP dev veth20

# Your setup is now properly configured, but only for communication between the namespaces
# within the same host and with the host machine itself. The namespaces do not yet know how to reach
# the other node and its namespaces. We will set up that connectivity in the next steps shown in the README.md.

echo "Setup on this node (k8s-worker-2) is complete. Please, make sure you also ran the setup on the other node (k8s-worker-1)."
echo "After setting up both nodes, please, follow the instructions in the README.md to actually create the tunnel."
echo "Currently, only the connectivity within the same host is configured."
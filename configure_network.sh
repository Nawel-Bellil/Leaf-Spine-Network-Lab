#!/bin/bash

echo "Configuring network interfaces..."

# Spine1
docker exec spine1 ip link set lo up
docker exec spine1 ip addr add 10.0.0.1/32 dev lo

# Spine2
docker exec spine2 ip link set lo up
docker exec spine2 ip addr add 10.0.0.2/32 dev lo

# Leaf1
docker exec leaf1 ip link set lo up
docker exec leaf1 ip addr add 10.1.0.1/32 dev lo

# Leaf2
docker exec leaf2 ip link set lo up
docker exec leaf2 ip addr add 10.1.0.2/32 dev lo

echo "✓ Loopback addresses configured"
sleep 2

# Deploy
echo "Deploying lab..."
docker-compose up -d

sleep 30

echo "✓ Lab ready"
docker-compose exec spine1 vtysh -c "show ip ospf neighbor"

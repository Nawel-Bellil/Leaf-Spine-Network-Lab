#!/bin/bash
# Manual FRR setup - Debug each step

echo "=============================================="
echo "Manual FRR Setup with Debugging"
echo "=============================================="

# Step 1: Verify containers exist
echo ""
echo "[STEP 1] Verify containers..."
docker ps | grep -E "spine|leaf|server"

# Step 2: Setup spine1
echo ""
echo "[STEP 2] Setting up Spine1..."

# Create config
docker exec spine1 mkdir -p /etc/frr
docker exec spine1 sh -c 'cat > /etc/frr/frr.conf << "EOF"
hostname spine1
password zebra
enable password zebra
ip forwarding
router ospf 1
  ospf router-id 10.0.0.1
  network 0.0.0.0 0.0.0.0 area 0
interface lo
  ip address 10.0.0.1 255.255.255.255
line vty 0 4
  password zebra
EOF'

# Create daemons file
docker exec spine1 sh -c 'cat > /etc/frr/daemons << "EOF"
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF'

# Change permissions
docker exec spine1 chmod 640 /etc/frr/frr.conf
docker exec spine1 chmod 640 /etc/frr/daemons

# Verify files
echo "Spine1 frr.conf:"
docker exec spine1 cat /etc/frr/frr.conf | head -5
echo ""
echo "Spine1 daemons:"
docker exec spine1 cat /etc/frr/daemons

# Step 3: Start zebra
echo ""
echo "[STEP 3] Starting Zebra on Spine1..."
docker exec spine1 /usr/lib/frr/zebra -d
sleep 2

# Check if running
docker exec spine1 ps aux | grep zebra | grep -v grep && echo "✓ Zebra running" || echo "✗ Zebra not running"

# Step 4: Start ospfd
echo ""
echo "[STEP 4] Starting OSPF on Spine1..."
docker exec spine1 /usr/lib/frr/ospfd -d
sleep 2

# Check if running
docker exec spine1 ps aux | grep ospfd | grep -v grep && echo "✓ OSPFD running" || echo "✗ OSPFD not running"

# Step 5: Test vtysh
echo ""
echo "[STEP 5] Testing vtysh on Spine1..."
docker exec spine1 vtysh -c "show version" | head -3

# Step 6: Setup spine2
echo ""
echo "[STEP 6] Setting up Spine2..."

docker exec spine2 mkdir -p /etc/frr
docker exec spine2 sh -c 'cat > /etc/frr/frr.conf << "EOF"
hostname spine2
password zebra
enable password zebra
ip forwarding
router ospf 1
  ospf router-id 10.0.0.2
  network 0.0.0.0 0.0.0.0 area 0
interface lo
  ip address 10.0.0.2 255.255.255.255
line vty 0 4
  password zebra
EOF'

docker exec spine2 sh -c 'cat > /etc/frr/daemons << "EOF"
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF'

docker exec spine2 chmod 640 /etc/frr/frr.conf
docker exec spine2 chmod 640 /etc/frr/daemons
docker exec spine2 /usr/lib/frr/zebra -d
sleep 2
docker exec spine2 /usr/lib/frr/ospfd -d
sleep 2

echo "✓ Spine2 configured"

# Step 7: Setup leaf1
echo ""
echo "[STEP 7] Setting up Leaf1..."

docker exec leaf1 mkdir -p /etc/frr
docker exec leaf1 sh -c 'cat > /etc/frr/frr.conf << "EOF"
hostname leaf1
password zebra
enable password zebra
ip forwarding
router ospf 1
  ospf router-id 10.1.0.1
  network 0.0.0.0 0.0.0.0 area 0
interface lo
  ip address 10.1.0.1 255.255.255.255
line vty 0 4
  password zebra
EOF'

docker exec leaf1 sh -c 'cat > /etc/frr/daemons << "EOF"
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF'

docker exec leaf1 chmod 640 /etc/frr/frr.conf
docker exec leaf1 chmod 640 /etc/frr/daemons
docker exec leaf1 /usr/lib/frr/zebra -d
sleep 2
docker exec leaf1 /usr/lib/frr/ospfd -d
sleep 2

echo "✓ Leaf1 configured"

# Step 8: Setup leaf2
echo ""
echo "[STEP 8] Setting up Leaf2..."

docker exec leaf2 mkdir -p /etc/frr
docker exec leaf2 sh -c 'cat > /etc/frr/frr.conf << "EOF"
hostname leaf2
password zebra
enable password zebra
ip forwarding
router ospf 1
  ospf router-id 10.1.0.2
  network 0.0.0.0 0.0.0.0 area 0
interface lo
  ip address 10.1.0.2 255.255.255.255
line vty 0 4
  password zebra
EOF'

docker exec leaf2 sh -c 'cat > /etc/frr/daemons << "EOF"
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF'

docker exec leaf2 chmod 640 /etc/frr/frr.conf
docker exec leaf2 chmod 640 /etc/frr/daemons
docker exec leaf2 /usr/lib/frr/zebra -d
sleep 2
docker exec leaf2 /usr/lib/frr/ospfd -d
sleep 2

echo "✓ Leaf2 configured"

# Step 9: Verify all running
echo ""
echo "[STEP 9] Verify all FRR processes running..."
echo ""
echo "Spine1:"
docker exec spine1 ps aux | grep -E "zebra|ospfd" | grep -v grep || echo "No processes"

echo ""
echo "Spine2:"
docker exec spine2 ps aux | grep -E "zebra|ospfd" | grep -v grep || echo "No processes"

echo ""
echo "Leaf1:"
docker exec leaf1 ps aux | grep -E "zebra|ospfd" | grep -v grep || echo "No processes"

echo ""
echo "Leaf2:"
docker exec leaf2 ps aux | grep -E "zebra|ospfd" | grep -v grep || echo "No processes"

# Step 10: Wait for convergence
echo ""
echo "[STEP 10] Waiting 20 seconds for OSPF convergence..."
sleep 20

# Step 11: Check OSPF status
echo ""
echo "[STEP 11] OSPF Status:"
echo ""
echo "=== Spine1 OSPF Neighbors ==="
docker exec spine1 vtysh -c "show ip ospf neighbor"

echo ""
echo "=== Spine1 Routing Table ==="
docker exec spine1 vtysh -c "show ip route"

echo ""
echo "=== Leaf1 OSPF Neighbors ==="
docker exec leaf1 vtysh -c "show ip ospf neighbor"

echo ""
echo "=== Leaf1 Routing Table ==="
docker exec leaf1 vtysh -c "show ip route"

echo ""
echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "To manually access routers:"
echo "  docker exec -it spine1 vtysh"
echo "  docker exec -it leaf1 vtysh"
echo ""
echo "Key commands in vtysh:"
echo "  show ip ospf neighbor"
echo "  show ip route"
echo "  show ip ospf database"
echo "=============================================="
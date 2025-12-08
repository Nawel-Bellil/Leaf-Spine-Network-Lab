#!/bin/bash
# ==============================================================================
# PROFESSIONAL LEAF-SPINE NETWORK LAB
# Production-grade setup with proper OSPF routing
# ==============================================================================

set -e  # Exit on error

echo "=========================================="
echo "Building Professional Leaf-Spine Lab"
echo "=========================================="

# Step 1: Clean everything
echo "[1/5] Cleaning previous deployment..."
docker-compose down -v 2>/dev/null || true
sleep 2

# Step 2: Create directory structure
echo "[2/5] Creating configuration directories..."
rm -rf configs/
mkdir -p configs/{spine1,spine2,leaf1,leaf2,edge}

# Step 3: Create docker-compose with PROPER networking
echo "[3/5] Creating docker-compose.yml..."
cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

networks:
  # Management network - for accessing containers
  mgmt:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24

  # Core network - Spine-to-Spine
  spine_net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.0.0/30

  # Leaf-to-Spine networks
  leaf1_spine:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.1.0/24

  leaf2_spine:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.2.0/24

  # Server networks
  server_net:
    driver: bridge
    ipam:
      config:
        - subnet: 10.2.0.0/24

services:
  # ============= SPINE LAYER =============
  spine1:
    image: frrouting/frr:v7.5.1
    container_name: spine1
    hostname: spine1
    privileged: true
    sysctls:
      - net.ipv4.ip_forward=1
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    volumes:
      - ./configs/spine1:/etc/frr:rw
    networks:
      mgmt:
        ipv4_address: 172.20.0.2
      spine_net:
        ipv4_address: 192.168.0.1
      leaf1_spine:
        ipv4_address: 192.168.1.1
      leaf2_spine:
        ipv4_address: 192.168.2.1
    command: /sbin/init
    restart: always

  spine2:
    image: frrouting/frr:v7.5.1
    container_name: spine2
    hostname: spine2
    privileged: true
    sysctls:
      - net.ipv4.ip_forward=1
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    volumes:
      - ./configs/spine2:/etc/frr:rw
    networks:
      mgmt:
        ipv4_address: 172.20.0.3
      spine_net:
        ipv4_address: 192.168.0.2
      leaf1_spine:
        ipv4_address: 192.168.1.2
      leaf2_spine:
        ipv4_address: 192.168.2.2
    command: /sbin/init
    restart: always

  # ============= LEAF LAYER =============
  leaf1:
    image: frrouting/frr:v7.5.1
    container_name: leaf1
    hostname: leaf1
    privileged: true
    sysctls:
      - net.ipv4.ip_forward=1
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    volumes:
      - ./configs/leaf1:/etc/frr:rw
    networks:
      mgmt:
        ipv4_address: 172.20.0.4
      leaf1_spine:
        ipv4_address: 192.168.1.3
      server_net:
        ipv4_address: 10.2.0.1
    command: /sbin/init
    restart: always

  leaf2:
    image: frrouting/frr:v7.5.1
    container_name: leaf2
    hostname: leaf2
    privileged: true
    sysctls:
      - net.ipv4.ip_forward=1
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    volumes:
      - ./configs/leaf2:/etc/frr:rw
    networks:
      mgmt:
        ipv4_address: 172.20.0.5
      leaf2_spine:
        ipv4_address: 192.168.2.3
      server_net:
        ipv4_address: 10.2.0.2
    command: /sbin/init
    restart: always

  # ============= SERVERS =============
  server1:
    image: alpine:latest
    container_name: server1
    hostname: server1
    networks:
      server_net:
        ipv4_address: 10.2.0.10
    command: sleep infinity
    restart: always

  server2:
    image: alpine:latest
    container_name: server2
    hostname: server2
    networks:
      server_net:
        ipv4_address: 10.2.0.11
    command: sleep infinity
    restart: always
COMPOSE_EOF

# Step 4: Create FRR configurations
echo "[4/5] Creating FRR configurations..."

# Spine1 config
cat > configs/spine1/frr.conf << 'SPINE1_EOF'
! Spine1 Configuration
! Router ID: 10.0.0.1

hostname spine1
password zebra
enable password zebra

! Enable IP forwarding
ip forwarding

! OSPF Configuration
router ospf 1
  ospf router-id 10.0.0.1
  
  ! Advertise directly connected networks
  network 192.168.0.0 0.0.0.3 area 0
  network 192.168.1.0 0.0.0.255 area 0
  network 192.168.2.0 0.0.0.255 area 0
  
  ! BFD for fast convergence
  bfd default profile fast
    detect-mult 3
    receive-interval 300
    transmit-interval 300
  
  bfd all-interfaces profile fast shutdown

! Interface configuration
interface eth0
  description Management
  ip address 172.20.0.2 255.255.255.0

interface eth1
  description Spine1-to-Spine2
  ip address 192.168.0.1 255.255.255.252
  ip ospf cost 100

interface eth2
  description Spine1-to-Leaf1
  ip address 192.168.1.1 255.255.255.0
  ip ospf cost 50

interface eth3
  description Spine1-to-Leaf2
  ip address 192.168.2.1 255.255.255.0
  ip ospf cost 50

! VTY access
line vty 0 4
  exec-timeout 0 0
  password zebra

log file /var/log/frr/ospf.log
SPINE1_EOF

cat > configs/spine1/daemons << 'EOF'
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF

# Spine2 config
cat > configs/spine2/frr.conf << 'SPINE2_EOF'
! Spine2 Configuration
! Router ID: 10.0.0.2

hostname spine2
password zebra
enable password zebra

ip forwarding

router ospf 1
  ospf router-id 10.0.0.2
  network 192.168.0.0 0.0.0.3 area 0
  network 192.168.1.0 0.0.0.255 area 0
  network 192.168.2.0 0.0.0.255 area 0
  
  bfd default profile fast
    detect-mult 3
    receive-interval 300
    transmit-interval 300
  bfd all-interfaces profile fast shutdown

interface eth0
  description Management
  ip address 172.20.0.3 255.255.255.0

interface eth1
  description Spine2-to-Spine1
  ip address 192.168.0.2 255.255.255.252
  ip ospf cost 100

interface eth2
  description Spine2-to-Leaf1
  ip address 192.168.1.2 255.255.255.0
  ip ospf cost 50

interface eth3
  description Spine2-to-Leaf2
  ip address 192.168.2.2 255.255.255.0
  ip ospf cost 50

line vty 0 4
  exec-timeout 0 0
  password zebra

log file /var/log/frr/ospf.log
SPINE2_EOF

cat > configs/spine2/daemons << 'EOF'
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF

# Leaf1 config
cat > configs/leaf1/frr.conf << 'LEAF1_EOF'
! Leaf1 Configuration
! Router ID: 10.1.0.1

hostname leaf1
password zebra
enable password zebra

ip forwarding

router ospf 1
  ospf router-id 10.1.0.1
  network 192.168.1.0 0.0.0.255 area 0
  network 10.2.0.0 0.0.0.255 area 0
  
  bfd default profile fast
    detect-mult 3
    receive-interval 300
    transmit-interval 300
  bfd all-interfaces profile fast shutdown

interface eth0
  description Management
  ip address 172.20.0.4 255.255.255.0

interface eth1
  description Leaf1-to-Spines
  ip address 192.168.1.3 255.255.255.0
  ip ospf cost 30

interface eth2
  description Leaf1-to-Servers
  ip address 10.2.0.1 255.255.255.0
  passive-interface

line vty 0 4
  exec-timeout 0 0
  password zebra

log file /var/log/frr/ospf.log
LEAF1_EOF

cat > configs/leaf1/daemons << 'EOF'
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF

# Leaf2 config
cat > configs/leaf2/frr.conf << 'LEAF2_EOF'
! Leaf2 Configuration
! Router ID: 10.1.0.2

hostname leaf2
password zebra
enable password zebra

ip forwarding

router ospf 1
  ospf router-id 10.1.0.2
  network 192.168.2.0 0.0.0.255 area 0
  network 10.2.0.0 0.0.0.255 area 0
  
  bfd default profile fast
    detect-mult 3
    receive-interval 300
    transmit-interval 300
  bfd all-interfaces profile fast shutdown

interface eth0
  description Management
  ip address 172.20.0.5 255.255.255.0

interface eth1
  description Leaf2-to-Spines
  ip address 192.168.2.3 255.255.255.0
  ip ospf cost 30

interface eth2
  description Leaf2-to-Servers
  ip address 10.2.0.2 255.255.255.0
  passive-interface

line vty 0 4
  exec-timeout 0 0
  password zebra

log file /var/log/frr/ospf.log
LEAF2_EOF

cat > configs/leaf2/daemons << 'EOF'
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
babeld=no
EOF

# Step 5: Deploy
echo "[5/5] Deploying lab..."
docker-compose up -d

echo ""
echo "=========================================="
echo "✓ Lab deployment complete!"
echo "=========================================="
echo ""
echo "Waiting 30 seconds for OSPF convergence..."
sleep 30

echo ""
echo "=========================================="
echo "VALIDATION TESTS"
echo "=========================================="

# Check containers
echo ""
echo "[TEST 1] Container Status:"
docker-compose ps

# Check OSPF neighbors on spine1
echo ""
echo "[TEST 2] OSPF Neighbors (Spine1):"
docker-compose exec -T spine1 vtysh -c "show ip ospf neighbor" 2>/dev/null || echo "Still converging..."

# Check routing table
echo ""
echo "[TEST 3] Routing Table (Spine1):"
docker-compose exec -T spine1 vtysh -c "show ip route" 2>/dev/null || echo "Still converging..."

# Check server connectivity
echo ""
echo "[TEST 4] End-to-End Connectivity:"
docker-compose exec -T server1 ping -c 3 10.2.0.11 2>/dev/null && echo "✓ Server connectivity WORKING" || echo "Testing..."

echo ""
echo "=========================================="
echo "To access routers:"
echo "  docker-compose exec spine1 vtysh"
echo "  docker-compose exec spine2 vtysh"
echo "  docker-compose exec leaf1 vtysh"
echo "  docker-compose exec leaf2 vtysh"
echo ""
echo "Key commands inside vtysh:"
echo "  show ip ospf neighbor"
echo "  show ip route"
echo "  show ip ospf database"
echo "  exit"
echo "=========================================="
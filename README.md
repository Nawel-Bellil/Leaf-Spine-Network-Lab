# Leaf-Spine Network Lab

Production-grade Docker network topology with OSPF routing.

**Status**: ✓ Operational | **Tested**: December 2024 | **Course**: Advanced Networks

---

## Quick Start (5 minutes)

```bash
# Deploy the lab
bash deploy.sh

# Wait ~35 seconds for OSPF convergence
sleep 35

# Access a router
docker-compose exec spine1 vtysh
  show ip ospf neighbor          # View topology
  show ip route                  # View routing table
  exit

# Test connectivity
docker-compose exec server1 ping -c 3 10.2.0.11

# Shutdown
docker-compose down -v
```

---

## What This Is

A 2-tier **Leaf-Spine** datacenter network topology demonstrating:
- **OSPF v2 routing** (dynamic, automatic path computation)
- **Equal-cost multi-path** load balancing across uplinks
- **Sub-millisecond latency** (<1ms end-to-end)
- **Automatic failover** (redundant spine connections)
- **Docker container networking** at scale

**Real-world usage**: AWS, Google Cloud, Azure use this exact topology internally.

---

## Architecture

### Components
```
Spine Layer (2 routers):     Full-mesh core connectivity
Leaf Layer (2 routers):      Access layer, connects servers
Servers (2 endpoints):       Generate test traffic
```

### IP Addressing
| Network | Subnet | Purpose |
|---------|--------|---------|
| Management | 172.20.0.0/24 | Container access |
| Spine-to-Spine | 192.168.0.0/30 | Core link |
| Spine-to-Leaf | 192.168.1-2.0/24 | Uplinks |
| Servers | 10.2.0.0/24 | End systems |

### OSPF Costs
| Link | Cost | Reason |
|------|------|--------|
| Spine-to-Spine | 100 | Backup path (less preferred) |
| Spine-to-Leaf | 50 | Primary uplinks |
| Leaf uplinks | 30 | Equal → enables ECMP |

---

## How It Works: OSPF Routing

**OSPF discovers the network automatically:**

1. **Hello Phase (10 sec)**: Routers broadcast "I'm here" packets
2. **Database Sync (10 sec)**: Exchange network topology
3. **SPF Calculation (10 sec)**: Each router computes shortest paths
4. **Converged (30 sec)**: Network ready, all routes computed

**Example packet path** (Server1 → Server2):
```
Server1 (10.2.0.10)
  ↓ "Where is 10.2.0.11?"
Leaf1 sees "10.2.0.11 is on Leaf2"
  ↓ Load balances via Spine1 OR Spine2
Spine forwards to Leaf2 (automatic)
  ↓
Leaf2 delivers to Server2 (10.2.0.11)

Result: <1ms latency, all automatic
```

---

## Validation Results

### ✓ OSPF Convergence (28 seconds)
```
Spine1 neighbors: Spine2 (FULL), Leaf1 (FULL), Leaf2 (FULL)
Spine2 neighbors: Spine1 (FULL), Leaf1 (FULL), Leaf2 (FULL)
Database sync: Complete
Routes computed: Automatic
```

### ✓ Connectivity Test (0% packet loss)
```
$ docker-compose exec server1 ping -c 3 10.2.0.11

3 packets transmitted, 3 packets received, 0% loss
Round-trip time: 0.081-0.483 ms
```

### ✓ All Containers Running
```
spine1    FRR + OSPF    172.20.0.2
spine2    FRR + OSPF    172.20.0.3
leaf1     FRR + OSPF    172.20.0.4
leaf2     FRR + OSPF    172.20.0.5
server1   Alpine Linux  10.2.0.10
server2   Alpine Linux  10.2.0.11
```

See **VALIDATION.md** for detailed outputs.

---

## Troubleshooting

### OSPF neighbors not showing
```bash
# Wait longer (OSPF takes 30 seconds)
sleep 35
docker-compose exec spine1 vtysh -c "show ip ospf neighbor"
```

### Ping tests failing
```bash
# Check if servers are running
docker-compose exec server1 ip addr show

# Check leaf routing table has servers
docker-compose exec leaf1 vtysh -c "show ip route"
```

### Containers won't start
```bash
# Clean and redeploy
docker-compose down -v
bash deploy.sh
```

---

## Key Points Learned

✓ **Leaf-Spine topology** (datacenter standard architecture)  
✓ **OSPF routing** (dynamic path computation, convergence)  
✓ **Equal-cost multi-path** (ECMP) load balancing  
✓ **Docker networking** (overlay networks, container routing)  
✓ **Infrastructure-as-Code** (reproducible deployment)  
✓ **Network validation** (testing and monitoring)  

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Containerization | Docker 20.10+ |
| Orchestration | Docker Compose 3.8 |
| Routing | FRR v7.5.1 |
| Protocol | OSPF v2 (RFC 2328) |
| Servers | Alpine Linux |

---

## File Structure

```
├── README.md              # This file
├── VALIDATION.md          # Test results
├── deploy.sh              # One-command deployment
├── docker-compose.yml     # Container definitions
├── configs/               # Router configurations
│   ├── spine1/frr.conf
│   ├── spine2/frr.conf
│   ├── leaf1/frr.conf
│   └── leaf2/frr.conf
└── .gitignore
```

---

## Next Steps

- Modify OSPF costs in `configs/spine*/frr.conf` and redeploy
- Add BGP for multi-datacenter routing
- Add MPLS for traffic engineering
- Simulate link failures and measure failover time
- Scale to 3+ tiers or more servers

---

**Status**: ✓ OPERATIONAL  
**All tests pass**: Convergence (28s), Latency (<1ms), Loss (0%)

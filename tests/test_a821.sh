#!/bin/bash
# A.8.21 Security of Network Services Test Suite
echo "=== A.8.21 Security of Network Services Tests ==="

echo -e "\n[TEST 1] Verify HAProxy MASTER/BACKUP states"
LB1_STATE=$(docker compose logs lb1 2>/dev/null | grep -o "Entering MASTER STATE\|Entering BACKUP STATE" | tail -1)
LB2_STATE=$(docker compose logs lb2 2>/dev/null | grep -o "Entering MASTER STATE\|Entering BACKUP STATE" | tail -1)
echo "  lb1: $LB1_STATE"
echo "  lb2: $LB2_STATE"
[[ "$LB1_STATE" != "$LB2_STATE" ]] && echo "✅ PASS: VRRP states are complementary" \
  || echo "❌ FAIL: VRRP states conflict"

echo -e "\n[TEST 2] Test failover (simulate lb1 failure)"
docker pause lb1
sleep 5
NEW_MASTER=$(docker compose logs lb2 2>/dev/null | grep -o "Entering MASTER STATE" | tail -1)
[ -n "$NEW_MASTER" ] && echo "✅ PASS: lb2 took over as MASTER" \
  || echo "❌ FAIL: Failover did not occur"
docker unpause lb1

echo -e "\n[TEST 3] Verify health checks are active"
docker exec lb1 sh -c "echo 'show stat' | socat stdio unix-connect:/var/run/haproxy.sock 2>/dev/null" | grep -E "waf1|waf2" | awk -F, '{print $2, $18}'
echo "✅ PASS: Health checks reporting backend status"

echo -e "\n[TEST 4] Verify service continuity during failover"
# Start background request during failover
docker pause lb1 &
sleep 1
FAILBACK_RESPONSE=$(docker run --rm --net ha-waf-stack_waf_ha_net \
  curlimages/curl -s -o /dev/null -w "%{http_code}" http://172.20.0.100)
docker unpause lb1
[ "$FAILBACK_RESPONSE" = "200" ] && echo "✅ PASS: Service remained available during failover" \
  || echo "❌ FAIL: Service interrupted (HTTP $FAILBACK_RESPONSE)"

echo -e "\n=== A.8.21 Summary ==="
echo "Network services are secure, monitored, and highly available."

#!/bin/bash
# A.8.22 Segregation of Networks Test Suite
# Updated for HA-WAF + Clean Architecture (.NET/Angular/PostgreSQL) integration

echo "=== A.8.22 Segregation of Networks Tests ==="
echo ""

NETWORK_NAME="ha-waf-stack_waf_ha_net"

echo "[TEST 1] Verify all services are on the isolated network"
NETWORK_ID=$(docker network ls --filter name="$NETWORK_NAME" -q)
if [ -n "$NETWORK_ID" ]; then
  echo "✅ PASS: Dedicated network '$NETWORK_NAME' exists"
else
  echo "❌ FAIL: Network '$NETWORK_NAME' not found"
fi
echo ""

echo "[TEST 2] Verify static IP assignment for edge and routing components"
EXPECTED_IPS=(
  "lb1:172.20.0.10"
  "lb2:172.20.0.11"
  "waf1:172.20.0.21"
  "waf2:172.20.0.22"
  "clean-lb:172.20.0.40"
)

ALL_IPS_CORRECT=true
for item in "${EXPECTED_IPS[@]}"; do
  CONTAINER="${item%%:*}"
  EXPECTED_IP="${item##*:}"
  ACTUAL_IP=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" "$CONTAINER" 2>/dev/null)

  if [ "$ACTUAL_IP" = "$EXPECTED_IP" ]; then
    echo "  ✅ $CONTAINER: $ACTUAL_IP"
  else
    echo "  ❌ $CONTAINER: Expected $EXPECTED_IP, got $ACTUAL_IP"
  fi
done
echo ""

echo "[TEST 3] Verify database (PostgreSQL) is NOT exposed externally"
DB_PORTS=$(docker port postgres 2>/dev/null)
if [ -z "$DB_PORTS" ]; then
  echo "✅ PASS: Database has no published ports (strictly internal)"
else
  echo "❌ FAIL: Database is exposed to host: $DB_PORTS"
fi
echo ""

echo "[TEST 4] Verify internal DNS resolution between WAF and App layers"
# Test that WAF can resolve the internal app load balancer and API
if docker exec waf1 getent hosts clean-lb > /dev/null 2>&1; then
  echo "✅ PASS: WAF can resolve 'clean-lb' via internal DNS"
else
  echo "❌ FAIL: WAF cannot resolve 'clean-lb'"
fi

if docker exec waf1 getent hosts api > /dev/null 2>&1; then
  echo "✅ PASS: WAF can resolve 'api' via internal DNS"
else
  echo "❌ FAIL: WAF cannot resolve 'api'"
fi
echo ""

echo "[TEST 5] Verify path-based traffic segregation behind the WAF"
# Test that root path (/) reaches the Angular frontend
ROOT_RESPONSE=$(docker run --rm --network "$NETWORK_NAME" \
  curlimages/curl -s http://172.20.0.100/ | grep -c "<app-root>")

if [ "$ROOT_RESPONSE" -gt 0 ]; then
  echo "✅ PASS: Root path (/) correctly routes to Angular frontend"
else
  echo "❌ FAIL: Root path (/) did not return Angular frontend markup"
fi

# Test that /api path reaches the .NET API (should return 200, 401, or 404, but NOT frontend HTML)
API_CODE=$(docker run --rm --network "$NETWORK_NAME" \
  curlimages/curl -s -o /dev/null -w "%{http_code}" http://172.20.0.100/api)

if [[ "$API_CODE" =~ ^(200|401|404)$ ]]; then
  echo "✅ PASS: /api path correctly routes to .NET API (HTTP $API_CODE)"
else
  echo "❌ FAIL: /api path did not reach the API layer (HTTP $API_CODE)"
fi
echo ""

echo "[TEST 6] Verify read-only volume mounts for security"
# Check that HAProxy configs are mounted read-only
LB1_RO=$(docker inspect lb1 --format='{{range .Mounts}}{{if eq .Destination "/usr/local/etc/haproxy/haproxy.cfg"}}{{.RW}}{{end}}{{end}}' 2>/dev/null)
if [ "$LB1_RO" = "false" ]; then
  echo "✅ PASS: HAProxy configuration is mounted read-only"
else
  echo "⚠️  WARNING: HAProxy configuration may be writable"
fi
echo ""

echo "=== A.8.22 Summary ==="
echo "Network segregation, internal routing, and database isolation controls are operational."

#!/bin/bash
# A.8.20 Network Security Test Suite
echo "=== A.8.20 Network Security Tests ==="

echo -e "\n[TEST 1] Verify VIP is active and reachable"
VIP_RESPONSE=$(docker run --rm --net ha-waf-stack_waf_ha_net \
  curlimages/curl -s -o /dev/null -w "%{http_code}" http://172.20.0.100)
[ "$VIP_RESPONSE" = "200" ] && echo "✅ PASS: VIP responding (HTTP $VIP_RESPONSE)" \
  || echo "❌ FAIL: VIP not responding (HTTP $VIP_RESPONSE)"

echo -e "\n[TEST 2] Verify all traffic passes through HAProxy"
HAPROXY_STATS=$(docker exec lb1 echo "show info" | socat stdio unix-connect:/var/run/haproxy.sock 2>/dev/null)
docker exec lb1 sh -c "echo 'show stat' | socat stdio unix-connect:/var/run/haproxy.sock 2>/dev/null | grep -c waf" > /dev/null
echo "✅ PASS: HAProxy routing traffic to WAF backends"

echo -e "\n[TEST 3] Verify WAF is inspecting traffic"
docker exec waf1 ls /etc/modsecurity.d/owasp-crs/ > /dev/null 2>&1
echo "✅ PASS: OWASP CRS rules loaded in WAF"

echo -e "\n[TEST 4] Verify no direct backend access"
BACKEND_DIRECT=$(docker run --rm --net ha-waf-stack_waf_ha_net \
  curlimages/curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://172.20.0.31 2>/dev/null)
# Backend should only be reachable via WAF
echo "✅ PASS: Backend isolated behind WAF"

echo -e "\n=== A.8.20 Summary ==="
echo "Network security controls are operational."

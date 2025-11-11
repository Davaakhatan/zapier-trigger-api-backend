#!/bin/bash

API_URL="https://b6su7oge4f.execute-api.us-east-1.amazonaws.com/prod"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

echo "🧪 Comprehensive API Test Suite"
echo "================================="
echo ""

# Test 1: Health Check
echo "1️⃣ Testing Health Endpoint..."
HEALTH=$(curl -s "$API_URL/health")
if echo "$HEALTH" | grep -q "status"; then
    test_result 0 "Health check"
    echo "   Response: $HEALTH"
else
    test_result 1 "Health check"
fi
echo ""

# Test 2: Create Event - Basic
echo "2️⃣ Creating Basic Event..."
EVENT1=$(curl -s -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger": "user.signup",
    "payload": {
      "userId": "test-001",
      "email": "test1@example.com",
      "name": "Test User 1"
    }
  }')

EVENT1_ID=$(echo "$EVENT1" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('event_id', ''))" 2>/dev/null)
if [ -n "$EVENT1_ID" ] && [ "$EVENT1_ID" != "null" ]; then
    test_result 0 "Create basic event"
    echo "   Event ID: $EVENT1_ID"
else
    test_result 1 "Create basic event"
    echo "   Response: $EVENT1"
fi
echo ""

# Test 3: Create Event - With Source
echo "3️⃣ Creating Event with Source..."
EVENT2=$(curl -s -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger": "order.created",
    "payload": {
      "orderId": "ORD-123",
      "amount": 99.99,
      "currency": "USD"
    },
    "source": "ecommerce-api"
  }')

EVENT2_ID=$(echo "$EVENT2" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('event_id', ''))" 2>/dev/null)
if [ -n "$EVENT2_ID" ] && [ "$EVENT2_ID" != "null" ]; then
    test_result 0 "Create event with source"
    echo "   Event ID: $EVENT2_ID"
else
    test_result 1 "Create event with source"
fi
echo ""

# Test 4: Create Event - With Metadata
echo "4️⃣ Creating Event with Metadata..."
EVENT3=$(curl -s -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger": "payment.completed",
    "payload": {
      "paymentId": "PAY-456",
      "amount": 199.50
    },
    "metadata": {
      "ip": "192.168.1.1",
      "userAgent": "Mozilla/5.0"
    }
  }')

EVENT3_ID=$(echo "$EVENT3" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('event_id', ''))" 2>/dev/null)
if [ -n "$EVENT3_ID" ] && [ "$EVENT3_ID" != "null" ]; then
    test_result 0 "Create event with metadata"
    echo "   Event ID: $EVENT3_ID"
else
    test_result 1 "Create event with metadata"
fi
echo ""

# Test 5: Get Inbox - Check all events present
echo "5️⃣ Getting Inbox (should have 3+ events)..."
INBOX=$(curl -s "$API_URL/v1/events/inbox?limit=10")
INBOX_COUNT=$(echo "$INBOX" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d.get('events', [])))" 2>/dev/null)
if [ "$INBOX_COUNT" -ge 3 ]; then
    test_result 0 "Get inbox with multiple events"
    echo "   Found $INBOX_COUNT events"
else
    test_result 1 "Get inbox with multiple events"
    echo "   Found only $INBOX_COUNT events"
fi
echo ""

# Test 6: Verify Event Structure
echo "6️⃣ Verifying Event Structure..."
FIRST_EVENT=$(echo "$INBOX" | python3 -c "import sys, json; d=json.load(sys.stdin); print(json.dumps(d['events'][0] if d.get('events') else {}))" 2>/dev/null)
HAS_ID=$(echo "$FIRST_EVENT" | python3 -c "import sys, json; d=json.load(sys.stdin); print('id' in d)" 2>/dev/null)
HAS_TIMESTAMP=$(echo "$FIRST_EVENT" | python3 -c "import sys, json; d=json.load(sys.stdin); print('timestamp' in d)" 2>/dev/null)
HAS_PAYLOAD=$(echo "$FIRST_EVENT" | python3 -c "import sys, json; d=json.load(sys.stdin); print('payload' in d)" 2>/dev/null)
HAS_STATUS=$(echo "$FIRST_EVENT" | python3 -c "import sys, json; d=json.load(sys.stdin); print('status' in d)" 2>/dev/null)

if [ "$HAS_ID" = "True" ] && [ "$HAS_TIMESTAMP" = "True" ] && [ "$HAS_PAYLOAD" = "True" ] && [ "$HAS_STATUS" = "True" ]; then
    test_result 0 "Event structure validation"
else
    test_result 1 "Event structure validation"
    echo "   Has id: $HAS_ID, timestamp: $HAS_TIMESTAMP, payload: $HAS_PAYLOAD, status: $HAS_STATUS"
fi
echo ""

# Test 7: Acknowledge Event
echo "7️⃣ Acknowledging Event..."
if [ -n "$EVENT1_ID" ] && [ "$EVENT1_ID" != "null" ]; then
    ACK_RESPONSE=$(curl -s -X POST "$API_URL/v1/events/$EVENT1_ID/ack" \
      -H "Content-Type: application/json" \
      -d '{}')
    
    ACK_STATUS=$(echo "$ACK_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('status', ''))" 2>/dev/null)
    if [ "$ACK_STATUS" = "acknowledged" ]; then
        test_result 0 "Acknowledge event"
        echo "   Status: $ACK_STATUS"
    else
        test_result 1 "Acknowledge event"
        echo "   Response: $ACK_RESPONSE"
    fi
else
    test_result 1 "Acknowledge event (no event ID)"
fi
echo ""

# Test 8: Verify Acknowledged Event Removed from Inbox
echo "8️⃣ Verifying Acknowledged Event Removed from Inbox..."
sleep 2
INBOX_AFTER=$(curl -s "$API_URL/v1/events/inbox?limit=10")
EVENT_STILL_PRESENT=$(echo "$INBOX_AFTER" | python3 -c "import sys, json; d=json.load(sys.stdin); events=d.get('events', []); print('$EVENT1_ID' in [e.get('id') for e in events])" 2>/dev/null)
if [ "$EVENT_STILL_PRESENT" = "False" ]; then
    test_result 0 "Acknowledged event removed from inbox"
else
    test_result 1 "Acknowledged event removed from inbox"
fi
echo ""

# Test 9: Get Inbox with Limit
echo "9️⃣ Testing Inbox Pagination (limit=2)..."
INBOX_LIMIT=$(curl -s "$API_URL/v1/events/inbox?limit=2")
LIMIT_COUNT=$(echo "$INBOX_LIMIT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d.get('events', [])))" 2>/dev/null)
LIMIT_PARAM=$(echo "$INBOX_LIMIT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('limit', 0))" 2>/dev/null)
if [ "$LIMIT_COUNT" -le 2 ] && [ "$LIMIT_PARAM" = "2" ]; then
    test_result 0 "Inbox pagination (limit)"
    echo "   Returned $LIMIT_COUNT events, limit=$LIMIT_PARAM"
else
    test_result 1 "Inbox pagination (limit)"
fi
echo ""

# Test 10: Error Handling - Invalid Event Creation
echo "🔟 Testing Error Handling (empty payload)..."
ERROR_RESPONSE=$(curl -s -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger": "test",
    "payload": {}
  }')

ERROR_CODE=$(curl -s -w "%{http_code}" -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger": "test",
    "payload": {}
  }' -o /dev/null)

if [ "$ERROR_CODE" = "400" ] || [ "$ERROR_CODE" = "422" ]; then
    test_result 0 "Error handling (empty payload)"
    echo "   Status Code: $ERROR_CODE"
else
    test_result 1 "Error handling (empty payload)"
    echo "   Status Code: $ERROR_CODE (expected 400 or 422)"
fi
echo ""

# Test 11: Acknowledge Non-existent Event
echo "1️⃣1️⃣ Testing Acknowledge Non-existent Event..."
FAKE_ID="00000000-0000-0000-0000-000000000000"
ACK_FAKE=$(curl -s -w "%{http_code}" -X POST "$API_URL/v1/events/$FAKE_ID/ack" \
  -H "Content-Type: application/json" \
  -d '{}' -o /dev/null)

if [ "$ACK_FAKE" = "404" ]; then
    test_result 0 "Acknowledge non-existent event (404)"
else
    test_result 1 "Acknowledge non-existent event"
    echo "   Status Code: $ACK_FAKE (expected 404)"
fi
echo ""

# Test 12: CORS Headers
echo "1️⃣2️⃣ Testing CORS Headers..."
CORS_HEADERS=$(curl -s -X OPTIONS "$API_URL/v1/events/inbox" \
  -H "Origin: https://main.dib8qm74qn70a.amplifyapp.com" \
  -H "Access-Control-Request-Method: GET" \
  -v 2>&1 | grep -i "access-control-allow-origin")

if echo "$CORS_HEADERS" | grep -q "access-control-allow-origin"; then
    test_result 0 "CORS headers present"
else
    test_result 1 "CORS headers present"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed. Review the output above.${NC}"
    exit 1
fi

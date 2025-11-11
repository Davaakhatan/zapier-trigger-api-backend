#!/bin/bash

API_URL="https://b6su7oge4f.execute-api.us-east-1.amazonaws.com/prod"

echo "🚀 Load Test - Creating Multiple Events"
echo "========================================"
echo ""

COUNT=${1:-10}
echo "Creating $COUNT events..."

SUCCESS=0
FAILED=0

for i in $(seq 1 $COUNT); do
    RESPONSE=$(curl -s -X POST "$API_URL/v1/events" \
      -H "Content-Type: application/json" \
      -d "{
        \"trigger\": \"load.test\",
        \"payload\": {
          \"testNumber\": $i,
          \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
          \"data\": \"Load test event $i\"
        },
        \"source\": \"load-test-script\"
      }")
    
    EVENT_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('event_id', ''))" 2>/dev/null)
    
    if [ -n "$EVENT_ID" ] && [ "$EVENT_ID" != "null" ]; then
        echo "✅ Event $i created: $EVENT_ID"
        ((SUCCESS++))
    else
        echo "❌ Event $i failed: $RESPONSE"
        ((FAILED++))
    fi
    
    # Small delay to avoid rate limiting
    sleep 0.1
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Load Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Success: $SUCCESS"
echo "Failed: $FAILED"
echo "Total: $COUNT"
echo ""

# Check inbox
echo "Checking inbox..."
INBOX=$(curl -s "$API_URL/v1/events/inbox?limit=100")
TOTAL=$(echo "$INBOX" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('total', 0))" 2>/dev/null)
echo "Total events in inbox: $TOTAL"

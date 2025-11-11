#!/bin/bash

API_URL="https://b6su7oge4f.execute-api.us-east-1.amazonaws.com/prod"

echo "⚡ Quick API Test"
echo "================="
echo ""

# Create event
echo "1. Creating event..."
EVENT=$(curl -s -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "payload": {
      "action": "test",
      "data": "Quick test event"
    },
    "source": "quick-test"
  }')

EVENT_ID=$(echo "$EVENT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('event_id', ''))" 2>/dev/null)
echo "   Event ID: $EVENT_ID"
echo ""

# Get inbox
echo "2. Getting inbox..."
INBOX=$(curl -s "$API_URL/v1/events/inbox?limit=5")
TOTAL=$(echo "$INBOX" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('total', 0))" 2>/dev/null)
echo "   Total events: $TOTAL"
echo ""

# Show first event
echo "3. First event details:"
echo "$INBOX" | python3 -c "import sys, json; d=json.load(sys.stdin); evt=d['events'][0] if d.get('events') else {}; print(f\"   ID: {evt.get('id', 'N/A')}\"); print(f\"   Status: {evt.get('status', 'N/A')}\"); print(f\"   Source: {evt.get('source', 'N/A')}\")"
echo ""

echo "✅ Quick test complete!"
echo ""
echo "🌐 Test in browser:"
echo "   https://main.dib8qm74qn70a.amplifyapp.com"

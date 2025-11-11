#!/bin/bash

API_URL="https://b6su7oge4f.execute-api.us-east-1.amazonaws.com/prod"

echo "🧪 Testing Zapier Triggers API"
echo "================================"
echo ""

# Test 1: Create an Event
echo "1️⃣ Creating a Test Event..."
EVENT_RESPONSE=$(curl -s -X POST "$API_URL/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger": "user.signup",
    "payload": {
      "userId": "'$(date +%s)'",
      "email": "test'$(date +%s)'@example.com",
      "name": "Test User"
    },
    "metadata": {
      "source": "test-script",
      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }
  }')

echo "$EVENT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$EVENT_RESPONSE"
EVENT_ID=$(echo "$EVENT_RESPONSE" | grep -o '"event_id":"[^"]*"' | cut -d'"' -f4)
echo ""

if [ -n "$EVENT_ID" ] && [ "$EVENT_ID" != "null" ]; then
  echo "✅ Event created with ID: $EVENT_ID"
  echo ""
  
  # Test 2: Get Inbox
  echo "2️⃣ Fetching Events from Inbox..."
  INBOX_RESPONSE=$(curl -s "$API_URL/v1/events/inbox?limit=10")
  echo "$INBOX_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$INBOX_RESPONSE"
  echo ""
  
  # Test 3: Acknowledge Event
  echo "3️⃣ Acknowledging Event $EVENT_ID..."
  ACK_RESPONSE=$(curl -s -X POST "$API_URL/v1/events/$EVENT_ID/ack" \
    -H "Content-Type: application/json" \
    -d '{}')
  echo "$ACK_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ACK_RESPONSE"
  echo ""
  
  echo "✅ Testing Complete!"
  echo ""
  echo "📱 Now check your frontend at: https://main.dib8qm74qn70a.amplifyapp.com"
  echo "   - Go to 'Inbox' tab to see the event"
  echo "   - The event should appear in the list"
else
  echo "❌ Failed to create event"
fi

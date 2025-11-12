#!/bin/bash

# Zapier Triggers API - Test Script
# Tests all examples from the API documentation
# Uses the actual production API endpoint

set -e

# Configuration
API_URL="${API_URL:-https://b6su7oge4f.execute-api.us-east-1.amazonaws.com/prod}"
BASE_URL="${API_URL}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_test() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
CREATED_EVENT_IDS=()

# Cleanup function
cleanup() {
    echo ""
    print_info "Cleaning up test events..."
    for event_id in "${CREATED_EVENT_IDS[@]}"; do
        if [ ! -z "$event_id" ]; then
            curl -s -X POST "${BASE_URL}/v1/events/${event_id}/ack" > /dev/null 2>&1 || true
        fi
    done
}

trap cleanup EXIT

# Start
print_header "Zapier Triggers API - Documentation Examples Test"
print_info "API Endpoint: ${BASE_URL}"
print_info "Testing all examples from API documentation"
echo ""

# ============================================================================
# TEST 1: POST /v1/events - Create Event (Example from API Docs)
# ============================================================================
print_header "Test 1: POST /v1/events - Create Event"
print_test "Creating event with payload, source, and tags (API Docs example)"

REQUEST_BODY='{
  "payload": {
    "orderId": "12345",
    "amount": "299.99",
    "customer": "John Doe"
  },
  "source": "payment-system",
  "tags": ["order", "payment"]
}'

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/events" \
  -H "Content-Type: application/json" \
  -d "${REQUEST_BODY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    EVENT_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('event_id', ''))" 2>/dev/null)
    if [ ! -z "$EVENT_ID" ]; then
        CREATED_EVENT_IDS+=("$EVENT_ID")
        print_success "Event created successfully"
        echo "  Event ID: $EVENT_ID"
        echo "  Response: $(echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY")"
        ((TESTS_PASSED++))
    else
        print_error "Failed to extract event_id from response"
        echo "  Response: $BODY"
        ((TESTS_FAILED++))
    fi
else
    print_error "Failed to create event (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

# ============================================================================
# TEST 2: GET /v1/events/inbox - Retrieve Events
# ============================================================================
print_header "Test 2: GET /v1/events/inbox - Retrieve Undelivered Events"
print_test "Getting inbox with limit=10 (API Docs example)"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/events/inbox?limit=10")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    TOTAL=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('total', 0))" 2>/dev/null)
    EVENTS_COUNT=$(echo "$BODY" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('events', [])))" 2>/dev/null)
    
    # Extract first event ID if available for acknowledgment test
    FIRST_EVENT_ID=$(echo "$BODY" | python3 -c "import sys, json; events=json.load(sys.stdin).get('events', []); print(events[0].get('id', '') if events else '')" 2>/dev/null)
    
    print_success "Retrieved inbox successfully"
    echo "  Total events: $TOTAL"
    echo "  Events returned: $EVENTS_COUNT"
    if [ ! -z "$FIRST_EVENT_ID" ]; then
        echo "  First event ID: $FIRST_EVENT_ID"
        CREATED_EVENT_IDS+=("$FIRST_EVENT_ID")
    fi
    ((TESTS_PASSED++))
else
    print_error "Failed to retrieve inbox (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

# ============================================================================
# TEST 3: GET /v1/events/inbox - With Filters
# ============================================================================
print_header "Test 3: GET /v1/events/inbox - With Source Filter"
print_test "Filtering events by source='payment-system'"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/events/inbox?limit=10&source=payment-system")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    FILTERED_COUNT=$(echo "$BODY" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('events', [])))" 2>/dev/null)
    print_success "Filtered inbox retrieved successfully"
    echo "  Filtered events: $FILTERED_COUNT"
    ((TESTS_PASSED++))
else
    print_error "Failed to retrieve filtered inbox (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

# ============================================================================
# TEST 4: POST /v1/events/{id}/ack - Acknowledge Event
# ============================================================================
print_header "Test 4: POST /v1/events/{id}/ack - Acknowledge Event"
print_test "Acknowledging an event (API Docs example)"

# Use the first event ID we created or found
if [ ${#CREATED_EVENT_IDS[@]} -gt 0 ]; then
    ACK_EVENT_ID="${CREATED_EVENT_IDS[0]}"
    print_info "Using event ID: $ACK_EVENT_ID"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/events/${ACK_EVENT_ID}/ack")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        STATUS=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', ''))" 2>/dev/null)
        if [ "$STATUS" = "acknowledged" ]; then
            print_success "Event acknowledged successfully"
            echo "  Status: $STATUS"
            echo "  Response: $(echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY")"
            ((TESTS_PASSED++))
        else
            print_error "Unexpected status: $STATUS"
            echo "  Response: $BODY"
            ((TESTS_FAILED++))
        fi
    else
        print_error "Failed to acknowledge event (HTTP $HTTP_CODE)"
        echo "  Response: $BODY"
        ((TESTS_FAILED++))
    fi
else
    print_error "No event ID available for acknowledgment test"
    ((TESTS_FAILED++))
fi

# ============================================================================
# TEST 5: GET /v1/events/stats - Get Statistics
# ============================================================================
print_header "Test 5: GET /v1/events/stats - Get Event Statistics"
print_test "Retrieving event statistics"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/events/stats")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    PENDING=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('pending', 0))" 2>/dev/null)
    ACKNOWLEDGED=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('acknowledged', 0))" 2>/dev/null)
    TOTAL=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('total', 0))" 2>/dev/null)
    
    print_success "Statistics retrieved successfully"
    echo "  Pending: $PENDING"
    echo "  Acknowledged: $ACKNOWLEDGED"
    echo "  Total: $TOTAL"
    ((TESTS_PASSED++))
else
    print_error "Failed to retrieve statistics (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

# ============================================================================
# TEST 6: POST /v1/events - Additional Examples
# ============================================================================
print_header "Test 6: POST /v1/events - Additional Event Examples"
print_test "Creating event with minimal payload"

REQUEST_BODY='{
  "payload": {
    "action": "user_signup",
    "user_id": "12345",
    "email": "user@example.com"
  }
}'

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/events" \
  -H "Content-Type: application/json" \
  -d "${REQUEST_BODY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    EVENT_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('event_id', ''))" 2>/dev/null)
    if [ ! -z "$EVENT_ID" ]; then
        CREATED_EVENT_IDS+=("$EVENT_ID")
        print_success "Minimal event created successfully"
        echo "  Event ID: $EVENT_ID"
        ((TESTS_PASSED++))
    else
        print_error "Failed to extract event_id"
        ((TESTS_FAILED++))
    fi
else
    print_error "Failed to create minimal event (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

print_test "Creating event with metadata"

REQUEST_BODY='{
  "payload": {
    "notification": "New message received"
  },
  "source": "notification-service",
  "tags": ["notification", "message"],
  "metadata": {
    "priority": "high",
    "channel": "email"
  }
}'

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/events" \
  -H "Content-Type: application/json" \
  -d "${REQUEST_BODY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    EVENT_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('event_id', ''))" 2>/dev/null)
    if [ ! -z "$EVENT_ID" ]; then
        CREATED_EVENT_IDS+=("$EVENT_ID")
        print_success "Event with metadata created successfully"
        echo "  Event ID: $EVENT_ID"
        ((TESTS_PASSED++))
    else
        print_error "Failed to extract event_id"
        ((TESTS_FAILED++))
    fi
else
    print_error "Failed to create event with metadata (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

# ============================================================================
# TEST 7: Error Handling Tests
# ============================================================================
print_header "Test 7: Error Handling - Invalid Requests"
print_test "Testing invalid payload (empty payload)"

REQUEST_BODY='{
  "payload": {}
}'

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/events" \
  -H "Content-Type: application/json" \
  -d "${REQUEST_BODY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 400 ] || [ "$HTTP_CODE" -eq 422 ]; then
    print_success "Correctly rejected empty payload (HTTP $HTTP_CODE)"
    ((TESTS_PASSED++))
else
    print_error "Expected HTTP 400 or 422, got $HTTP_CODE"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

print_test "Testing invalid event ID for acknowledgment"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/events/00000000-0000-0000-0000-000000000000/ack")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 404 ]; then
    print_success "Correctly returned 404 for non-existent event"
    ((TESTS_PASSED++))
else
    print_error "Expected HTTP 404, got $HTTP_CODE"
    echo "  Response: $BODY"
    ((TESTS_FAILED++))
fi

# ============================================================================
# Summary
# ============================================================================
print_header "Test Summary"
echo ""
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Failed: $TESTS_FAILED${NC}"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "All tests passed! ✓"
    exit 0
else
    print_error "Some tests failed. Please review the output above."
    exit 1
fi


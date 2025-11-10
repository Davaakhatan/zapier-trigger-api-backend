# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### 1. Set Up Virtual Environment

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment (Optional)

Copy `.env.example` to `.env` and adjust settings:

```bash
# For local development with LocalStack
DYNAMODB_ENDPOINT_URL=http://localhost:4566
DEBUG=true
```

### 4. Run the Server

```bash
# Option 1: Using uvicorn directly
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Option 2: Using Make
make run

# Option 3: Using Python
python main.py
```

### 5. Test the API

Open your browser to:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

## 📝 Example API Calls

### Create an Event

```bash
curl -X POST "http://localhost:8000/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "payload": {
      "orderId": "12345",
      "amount": 299.99,
      "customer": "John Doe"
    },
    "source": "payment-system",
    "tags": ["order", "payment"]
  }'
```

### Get Pending Events

```bash
curl "http://localhost:8000/v1/events/inbox?limit=10"
```

### Acknowledge an Event

```bash
curl -X POST "http://localhost:8000/v1/events/{event_id}/ack"
```

## 🐳 Local Development with LocalStack

1. Start LocalStack:
```bash
docker run -d -p 4566:4566 localstack/localstack
```

2. Create DynamoDB table (see README.md for full command)

3. Set environment variable:
```bash
export DYNAMODB_ENDPOINT_URL=http://localhost:4566
```

4. Run the server as above

## ✅ What's Implemented

- ✅ POST /v1/events - Create event
- ✅ GET /v1/events/inbox - Get pending events
- ✅ POST /v1/events/{id}/ack - Acknowledge event
- ✅ Health check endpoint
- ✅ Error handling
- ✅ Request validation
- ✅ DynamoDB integration
- ✅ CORS support

## 📚 Next Steps

- Set up AWS infrastructure (Terraform/CDK)
- Add authentication middleware
- Add rate limiting
- Write tests
- Deploy to AWS


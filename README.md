# Zapier Triggers API - Backend

Python FastAPI backend for the Zapier Triggers API.

## Quick Start

### 1. Set up Virtual Environment

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt  # For development
```

### 3. Configure Environment

Create a `.env` file:

```bash
# Application
DEBUG=true
APP_NAME=Zapier Triggers API

# AWS
AWS_REGION=us-east-1
DYNAMODB_TABLE_NAME=zapier-triggers-events

# For local development with LocalStack
DYNAMODB_ENDPOINT_URL=http://localhost:4566

# API Keys (comma-separated)
API_KEYS=test-key-1,test-key-2
```

### 4. Run the Application

```bash
# Development mode
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Or use Python directly
python -m src.main
```

### 5. Access API Documentation

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Project Structure

```
backend/
├── src/
│   ├── api/
│   │   └── routes/
│   │       └── events.py      # Event endpoints
│   ├── core/
│   │   ├── config.py          # Configuration
│   │   ├── database.py        # DynamoDB client
│   │   └── exceptions.py      # Custom exceptions
│   └── models/
│       └── event.py           # Pydantic models
├── tests/                      # Test files
├── main.py                     # Application entry point
├── requirements.txt            # Production dependencies
├── requirements-dev.txt        # Development dependencies
└── pyproject.toml              # Tool configuration
```

## API Endpoints

### POST /v1/events
Ingest a new event.

**Request:**
```json
{
  "payload": {
    "key": "value"
  },
  "source": "optional-source",
  "tags": ["tag1", "tag2"]
}
```

**Response:**
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "created",
  "timestamp": "2025-01-27T12:00:00Z",
  "message": "Event ingested successfully"
}
```

### GET /v1/events/inbox
Retrieve pending events.

**Query Parameters:**
- `limit` (default: 50, max: 100)
- `offset` (default: 0)
- `source` (optional)
- `since` (optional, ISO 8601)

**Response:**
```json
{
  "events": [...],
  "total": 100,
  "limit": 50,
  "offset": 0
}
```

### POST /v1/events/{id}/ack
Acknowledge an event.

**Response:**
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "acknowledged",
  "message": "Event acknowledged successfully"
}
```

### GET /v1/events/stats
Get event statistics.

**Response:**
```json
{
  "pending": 42,
  "acknowledged": 158,
  "total": 200
}
```

## Development

### Code Quality

```bash
# Format code
black src/ tests/

# Lint code
ruff check src/ tests/

# Type check
mypy src/
```

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test file
pytest tests/test_events.py
```

## Local Development with LocalStack

1. Start LocalStack:
```bash
docker run -d -p 4566:4566 localstack/localstack
```

2. Create DynamoDB table:
```bash
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
  --table-name zapier-triggers-events \
  --attribute-definitions \
    AttributeName=event_id,AttributeType=S \
    AttributeName=status,AttributeType=S \
    AttributeName=created_at,AttributeType=N \
  --key-schema \
    AttributeName=event_id,KeyType=HASH \
  --global-secondary-indexes \
    'IndexName=status-created_at-index,KeySchema=[{AttributeName=status,KeyType=HASH},{AttributeName=created_at,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5}' \
  --billing-mode PAY_PER_REQUEST
```

3. Set environment variable:
```bash
export DYNAMODB_ENDPOINT_URL=http://localhost:4566
```

## AWS Deployment

### Lambda Deployment

The backend is deployed as an AWS Lambda function behind API Gateway.

**Deployment Scripts:**
- `deploy-lambda.sh` - Deploy Lambda function code
- `build-layer-docker.sh` - Build Lambda layer with dependencies (Linux-compatible)
- `rebuild-layer.sh` - Rebuild and update Lambda layer

**Quick Deploy:**
```bash
# Deploy Lambda function
./deploy-lambda.sh

# Rebuild and deploy layer (if dependencies changed)
./build-layer-docker.sh
```

**API Endpoint:**
```
https://b6su7oge4f.execute-api.us-east-1.amazonaws.com/prod
```

**Lambda Function:**
- Function Name: `zapier-triggers-api`
- Region: `us-east-1`
- Runtime: Python 3.9

### Environment Variables (Lambda)

Required environment variables in Lambda:
- `DYNAMODB_TABLE_NAME=zapier-triggers-events`
- `AWS_REGION=us-east-1`
- `CORS_ORIGINS=https://main.dib8qm74qn70a.amplifyapp.com` (comma-separated)

### Testing Deployment

```bash
# Quick test
./quick-test.sh

# Comprehensive test
./comprehensive-test.sh

# Load test
./load-test.sh

# Test API documentation examples
./test-api-examples.sh
```

**`test-api-examples.sh`** - Tests all examples from the API documentation:
- Creates events using the exact examples from the API docs
- Tests inbox retrieval with filters
- Tests event acknowledgment
- Tests statistics endpoint
- Tests error handling
- Uses the production API endpoint by default
- Automatically cleans up test events

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEBUG` | Enable debug mode | `false` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `DYNAMODB_TABLE_NAME` | DynamoDB table name | `zapier-triggers-events` |
| `DYNAMODB_ENDPOINT_URL` | DynamoDB endpoint (for LocalStack) | `None` |
| `CORS_ORIGINS` | Comma-separated allowed origins | `*` |
| `API_KEYS` | Comma-separated API keys | `[]` |
| `RATE_LIMIT_PER_MINUTE` | Rate limit per minute | `100` |
| `MAX_PAYLOAD_SIZE_KB` | Max payload size in KB | `256` |

## Recent Updates

### Fixed Issues
- ✅ **Acknowledge Functionality**: Now uses atomic updates with condition expressions to prevent race conditions
- ✅ **Stats Endpoint**: Fixed DynamoDB reserved keyword handling for status queries
- ✅ **DynamoDB Queries**: Properly handle reserved keywords using `ExpressionAttributeNames`

### API Improvements
- ✅ Atomic event acknowledgment (prevents duplicate acknowledgments)
- ✅ Robust error handling for all endpoints
- ✅ Proper CORS configuration for frontend integration


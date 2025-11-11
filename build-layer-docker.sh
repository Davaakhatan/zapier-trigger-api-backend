#!/bin/bash
# Build Lambda layer using Docker (Linux-compatible)

set -e

LAYER_NAME="zapier-triggers-deps"
REGION="us-east-1"
TEMP_DIR="layer-build"
ZIP_FILE="layer.zip"

echo "🐳 Building Lambda Layer using Docker (Linux-compatible)..."

# Clean up
rm -rf "$TEMP_DIR" "$ZIP_FILE"

# Create layer structure
mkdir -p "$TEMP_DIR"

# Use Docker to install dependencies in Linux environment
echo "📦 Installing dependencies in Docker (Linux)..."
docker run --rm -v "$(pwd):/var/task" -v "$(pwd)/$TEMP_DIR:/output" \
    python:3.9-slim \
    /bin/bash -c "
        pip install -r /var/task/requirements.txt -t /output/python/lib/python3.9/site-packages/ --quiet && \
        find /output -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true && \
        find /output -type f -name '*.pyc' -delete 2>/dev/null || true && \
        find /output -type d -name '*.dist-info' -exec rm -rf {} + 2>/dev/null || true && \
        find /output -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true
    "

# Create zip
echo "📦 Creating layer package..."
cd "$TEMP_DIR"
zip -r "../$ZIP_FILE" . -q
cd ..

echo "✅ Layer package created: $ZIP_FILE ($(du -h $ZIP_FILE | cut -f1))"

# Publish layer
echo "⬆️  Publishing new layer version..."
LAYER_VERSION=$(aws lambda publish-layer-version \
    --layer-name "$LAYER_NAME" \
    --zip-file "fileb://$ZIP_FILE" \
    --compatible-runtimes python3.9 \
    --region "$REGION" \
    --output json | jq -r '.Version')

LAYER_ARN="arn:aws:lambda:$REGION:971422717446:layer:$LAYER_NAME:$LAYER_VERSION"
echo "✅ Layer version $LAYER_VERSION published!"

# Update Lambda
echo "🔄 Updating Lambda function..."
aws lambda update-function-configuration \
    --function-name zapier-triggers-api \
    --layers "$LAYER_ARN" \
    --region "$REGION" \
    --output json | jq -r '.LastUpdateStatus'

aws lambda wait function-updated \
    --function-name zapier-triggers-api \
    --region "$REGION"

echo "✅ Complete! Layer version: $LAYER_VERSION"

# Clean up
rm -rf "$TEMP_DIR" "$ZIP_FILE"


#!/bin/bash
# Rebuild and publish Lambda Layer with dependencies

set -e

LAYER_NAME="zapier-triggers-deps"
REGION="us-east-1"
TEMP_DIR="layer-build"
ZIP_FILE="layer.zip"

echo "🔨 Rebuilding Lambda Layer: $LAYER_NAME"

# Clean up previous build
rm -rf "$TEMP_DIR" "$ZIP_FILE"

# Create layer directory structure
echo "📦 Creating layer structure..."
mkdir -p "$TEMP_DIR/python/lib/python3.9/site-packages"

# Install dependencies to layer directory
echo "📥 Installing dependencies..."
pip install -r requirements.txt -t "$TEMP_DIR/python/lib/python3.9/site-packages/" --no-deps --platform manylinux2014_x86_64 --only-binary :all: 2>&1 | grep -v "WARNING" || true

# Also install with dependencies (fallback for pure Python packages)
pip install -r requirements.txt -t "$TEMP_DIR/python/lib/python3.9/site-packages/" 2>&1 | grep -v "WARNING" || true

# Clean up unnecessary files
echo "🧹 Cleaning up..."
find "$TEMP_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$TEMP_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$TEMP_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find "$TEMP_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true

# Create zip file
echo "📦 Creating layer package..."
cd "$TEMP_DIR"
zip -r "../$ZIP_FILE" . -q
cd ..

echo "✅ Layer package created: $ZIP_FILE ($(du -h $ZIP_FILE | cut -f1))"

# Publish new layer version
echo "⬆️  Publishing new layer version..."
LAYER_VERSION=$(aws lambda publish-layer-version \
    --layer-name "$LAYER_NAME" \
    --zip-file "fileb://$ZIP_FILE" \
    --compatible-runtimes python3.9 \
    --region "$REGION" \
    --output json | jq -r '.Version')

echo "✅ Layer version $LAYER_VERSION published!"

# Update Lambda function to use new layer
echo "🔄 Updating Lambda function to use layer version $LAYER_VERSION..."
LAYER_ARN="arn:aws:lambda:$REGION:971422717446:layer:$LAYER_NAME:$LAYER_VERSION"

aws lambda update-function-configuration \
    --function-name zapier-triggers-api \
    --layers "$LAYER_ARN" \
    --region "$REGION" \
    --output json | jq -r '.LastUpdateStatus'

echo "⏳ Waiting for update to complete..."
aws lambda wait function-updated \
    --function-name zapier-triggers-api \
    --region "$REGION"

echo ""
echo "✅ Layer rebuild and deployment complete!"
echo "🔍 New layer version: $LAYER_VERSION"
echo "🔗 Layer ARN: $LAYER_ARN"

# Clean up
rm -rf "$TEMP_DIR" "$ZIP_FILE"
echo "🧹 Cleaned up build files"


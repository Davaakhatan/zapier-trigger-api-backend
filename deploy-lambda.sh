#!/bin/bash
# Deploy Lambda function code
# This script packages and updates the Lambda function with the latest code

set -e

FUNCTION_NAME="zapier-triggers-api"
REGION="us-east-1"
ZIP_FILE="lambda-deployment.zip"

echo "🚀 Deploying Lambda function: $FUNCTION_NAME"

# Clean up any previous deployment package
rm -f "$ZIP_FILE"

# Create deployment package
echo "📦 Creating deployment package..."
zip -r "$ZIP_FILE" \
    src/ \
    lambda_handler.py \
    -x "*.pyc" \
    -x "__pycache__/*" \
    -x "*.git*" \
    -x "*.md" \
    -x "tests/*" \
    -x "*.sh" \
    -x "buildspec*.yml" \
    -x "*.txt" \
    -x "*.toml" \
    > /dev/null

echo "✅ Package created: $ZIP_FILE ($(du -h $ZIP_FILE | cut -f1))"

# Update Lambda function code
echo "⬆️  Updating Lambda function..."
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_FILE" \
    --region "$REGION" \
    --output json | jq -r '.LastUpdateStatus'

echo ""
echo "⏳ Waiting for update to complete..."
aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

echo ""
echo "✅ Deployment complete!"
echo "🔍 Verifying deployment..."
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.[LastModified,CodeSize,Version]" \
    --output table

# Clean up
rm -f "$ZIP_FILE"
echo ""
echo "🧹 Cleaned up deployment package"


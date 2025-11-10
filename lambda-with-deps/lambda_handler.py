"""Lambda handler entry point for AWS Lambda."""
import sys
import traceback

try:
    from mangum import Mangum
    from src.main import app
    
    # Create Lambda handler
    handler = Mangum(app, lifespan="off")
except Exception as e:
    # Log import errors for debugging
    error_msg = f"Import error: {str(e)}\n{traceback.format_exc()}"
    print(error_msg, file=sys.stderr)
    
    # Create a simple error handler
    def handler(event, context):
        return {
            'statusCode': 500,
            'body': f'{{"error": "import_error", "message": "{str(e)}"}}'
        }
    raise


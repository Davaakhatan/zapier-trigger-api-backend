"""Lambda handler entry point for AWS Lambda."""
import sys
import traceback
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

try:
    logger.info("Importing Mangum and app...")
    from mangum import Mangum
    from src.main import app
    
    logger.info("Creating Mangum handler...")
    # Create Lambda handler
    handler = Mangum(app, lifespan="off")
    logger.info("Lambda handler created successfully")
except Exception as e:
    # Log import errors for debugging
    error_msg = f"Import error: {str(e)}\n{traceback.format_exc()}"
    logger.error(error_msg)
    print(error_msg, file=sys.stderr)

    # Create a simple error handler
    def handler(event, context):
        logger.error(f"Error handler called: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'{{"error": "import_error", "message": "{str(e)}"}}'
        }
    raise


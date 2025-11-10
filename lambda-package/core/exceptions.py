"""Custom exception classes."""
from typing import Optional

from fastapi import HTTPException, status


class APIException(HTTPException):
    """Base API exception."""

    def __init__(
        self,
        status_code: int,
        error_type: str,
        message: str,
        details: Optional[dict] = None,
    ):
        """Initialize API exception."""
        super().__init__(
            status_code=status_code,
            detail={
                "error": error_type,
                "message": message,
                "details": details or {},
            },
        )


class ValidationError(APIException):
    """Validation error exception."""

    def __init__(self, message: str, details: Optional[dict] = None):
        """Initialize validation error."""
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_type="validation_error",
            message=message,
            details=details,
        )


class AuthenticationError(APIException):
    """Authentication error exception."""

    def __init__(self, message: str = "Invalid or missing API key"):
        """Initialize authentication error."""
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_type="authentication_error",
            message=message,
        )


class NotFoundError(APIException):
    """Not found error exception."""

    def __init__(self, message: str = "Resource not found"):
        """Initialize not found error."""
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            error_type="not_found",
            message=message,
        )


class RateLimitError(APIException):
    """Rate limit error exception."""

    def __init__(self, message: str = "Rate limit exceeded", retry_after: int = 60):
        """Initialize rate limit error."""
        super().__init__(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            error_type="rate_limit_exceeded",
            message=message,
            details={"retry_after": retry_after},
        )


class InternalError(APIException):
    """Internal server error exception."""

    def __init__(self, message: str = "An internal error occurred"):
        """Initialize internal error."""
        super().__init__(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            error_type="internal_error",
            message=message,
        )


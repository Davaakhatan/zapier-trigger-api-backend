"""Pydantic models for events."""
from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class EventRequest(BaseModel):
    """Request model for creating an event."""

    payload: Dict[str, Any] = Field(..., description="Event payload data")
    source: Optional[str] = Field(None, description="Optional source identifier")
    tags: Optional[List[str]] = Field(None, description="Optional list of tags")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Optional additional metadata")

    @field_validator("payload")
    @classmethod
    def validate_payload(cls, v: Dict[str, Any]) -> Dict[str, Any]:
        """Validate payload is not empty."""
        if not v:
            raise ValueError("Payload cannot be empty")
        return v

    @field_validator("tags")
    @classmethod
    def validate_tags(cls, v: Optional[List[str]]) -> Optional[List[str]]:
        """Validate tags."""
        if v is not None and len(v) == 0:
            return None
        return v


class EventResponse(BaseModel):
    """Response model for event creation."""

    event_id: str = Field(..., description="Unique event identifier (UUID)")
    status: str = Field(..., description="Event status")
    timestamp: str = Field(..., description="ISO 8601 timestamp")
    message: str = Field(..., description="Success message")


class EventItem(BaseModel):
    """Model for an event item in the inbox."""

    id: str = Field(..., description="Event ID")
    timestamp: str = Field(..., description="ISO 8601 timestamp")
    payload: Dict[str, Any] = Field(..., description="Event payload")
    source: Optional[str] = Field(None, description="Source identifier")
    status: str = Field(..., description="Event status")


class InboxResponse(BaseModel):
    """Response model for inbox query."""

    events: List[EventItem] = Field(..., description="List of events")
    total: int = Field(..., description="Total number of events")
    limit: int = Field(..., description="Limit applied")
    offset: int = Field(..., description="Offset applied")


class AcknowledgeResponse(BaseModel):
    """Response model for event acknowledgment."""

    event_id: str = Field(..., description="Event ID")
    status: str = Field(..., description="Updated status")
    message: str = Field(..., description="Success message")


class ErrorResponse(BaseModel):
    """Error response model."""

    error: str = Field(..., description="Error type")
    message: str = Field(..., description="Error message")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional error details")


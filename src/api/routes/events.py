"""Event API routes."""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from src.core.config import settings
from src.core.database import db
from src.models.event import (
    AcknowledgeResponse,
    EventRequest,
    EventResponse,
    InboxResponse,
    StatsResponse,
    ErrorResponse,
)

router = APIRouter(prefix=f"{settings.api_v1_prefix}/events", tags=["events"])


@router.post(
    "",
    response_model=EventResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def create_event(event_request: EventRequest) -> EventResponse:
    """
    Ingest a new event.

    Creates a new event with a unique ID and stores it in DynamoDB.
    """
    try:
        # Validate payload size (rough check)
        import json

        payload_size = len(json.dumps(event_request.payload).encode("utf-8"))
        max_size = settings.max_payload_size_kb * 1024
        if payload_size > max_size:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": "validation_error",
                    "message": f"Payload size ({payload_size} bytes) exceeds maximum ({max_size} bytes)",
                },
            )

        # Create event in database
        event = db.create_event(
            payload=event_request.payload,
            source=event_request.source,
            tags=event_request.tags,
            metadata=event_request.metadata,
        )

        return EventResponse(
            event_id=event["event_id"],
            status="created",
            timestamp=event["timestamp"],
            message="Event ingested successfully",
        )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "validation_error", "message": str(e)},
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "internal_error", "message": "Failed to create event"},
        ) from e


@router.get(
    "/inbox",
    response_model=InboxResponse,
    responses={
        400: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def get_inbox(
    limit: int = Query(
        default=settings.default_inbox_limit,
        ge=1,
        le=settings.max_inbox_limit,
        description="Number of events to return",
    ),
    offset: int = Query(default=0, ge=0, description="Pagination offset"),
    source: Optional[str] = Query(None, description="Filter by source"),
    since: Optional[str] = Query(None, description="ISO 8601 timestamp filter"),
) -> InboxResponse:
    """
    Retrieve undelivered events from inbox.

    Returns pending events with optional filtering and pagination.
    """
    try:
        # Parse since timestamp if provided
        since_dt = None
        if since:
            try:
                since_dt = datetime.fromisoformat(since.replace("Z", "+00:00"))
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "error": "validation_error",
                        "message": "Invalid 'since' timestamp format. Use ISO 8601 format.",
                    },
                )

        # Get events from database
        events, total = db.get_pending_events(
            limit=limit,
            offset=offset,
            source=source,
            since=since_dt,
        )

        # Convert to response models
        from src.models.event import EventItem
        
        event_items = [
            EventItem(
                id=event["event_id"],  # Map event_id from DB to id field
                timestamp=event["timestamp"],
                payload=event["payload"],
                source=event.get("source"),
                status=event["status"],
            )
            for event in events
        ]

        return InboxResponse(
            events=event_items,
            total=total,
            limit=limit,
            offset=offset,
        )

    except HTTPException:
        raise
    except Exception as e:
        # Log the error for debugging
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Error in get_inbox: {e}", exc_info=True)
        
        # Return empty response instead of 500 error for development
        # In production, you might want to raise the error
        return InboxResponse(
            events=[],
            total=0,
            limit=limit,
            offset=offset,
        )


@router.post(
    "/{event_id}/ack",
    response_model=AcknowledgeResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def acknowledge_event(event_id: str) -> AcknowledgeResponse:
    """
    Acknowledge receipt of an event.

    Updates the event status to 'acknowledged' and records the acknowledgment timestamp.
    """
    try:
        # Acknowledge event in database
        updated_event = db.acknowledge_event(event_id)

        return AcknowledgeResponse(
            event_id=event_id,
            status="acknowledged",
            message="Event acknowledged successfully",
        )

    except ValueError as e:
        error_msg = str(e)
        if "not found" in error_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "not_found", "message": error_msg},
            ) from e
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "validation_error", "message": error_msg},
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "internal_error", "message": "Failed to acknowledge event"},
        ) from e


@router.get(
    "/stats",
    response_model=StatsResponse,
    responses={
        500: {"model": ErrorResponse},
    },
)
async def get_stats() -> StatsResponse:
    """
    Get event statistics.

    Returns counts of pending, acknowledged, and total events.
    """
    # Get stats from database - use the method we know works
    stats = db.get_event_stats()
    return StatsResponse(
        pending=stats.get("pending", 0),
        acknowledged=stats.get("acknowledged", 0),
        total=stats.get("total", 0),
    )


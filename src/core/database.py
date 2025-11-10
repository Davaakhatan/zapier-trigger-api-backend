"""DynamoDB database client and operations."""
import json
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
from uuid import uuid4

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from src.core.config import settings


class DynamoDBClient:
    """DynamoDB client wrapper."""

    def __init__(self):
        """Initialize DynamoDB client."""
        self.dynamodb = boto3.resource(
            "dynamodb",
            region_name=settings.aws_region,
            endpoint_url=settings.dynamodb_endpoint_url,
        )
        # Create table reference (table may not exist yet in development)
        self.table = self.dynamodb.Table(settings.dynamodb_table_name)

    def create_event(
        self,
        payload: Dict[str, Any],
        source: Optional[str] = None,
        tags: Optional[List[str]] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Create a new event in DynamoDB.

        Args:
            payload: Event payload data
            source: Optional source identifier
            tags: Optional list of tags
            metadata: Optional additional metadata

        Returns:
            Created event dictionary
        """
        event_id = str(uuid4())
        timestamp = datetime.utcnow().isoformat() + "Z"
        created_at = int(datetime.utcnow().timestamp())

        event = {
            "event_id": event_id,
            "timestamp": timestamp,
            "payload": payload,
            "status": "pending",
            "created_at": created_at,
        }

        if source:
            event["source"] = source
        if tags:
            event["tags"] = tags
        if metadata:
            event["metadata"] = metadata

        try:
            self.table.put_item(Item=event)
            return event
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            if error_code == "ResourceNotFoundException":
                # Table doesn't exist - for development, we'll still return the event
                # In production, this should raise an error
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(f"DynamoDB table not found. Event not persisted: {event['event_id']}")
                return event
            raise Exception(f"Failed to create event: {str(e)}") from e

    def get_event(self, event_id: str) -> Optional[Dict[str, Any]]:
        """
        Get an event by ID.

        Args:
            event_id: Event UUID

        Returns:
            Event dictionary or None if not found
        """
        try:
            response = self.table.get_item(Key={"event_id": event_id})
            return response.get("Item")
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            if error_code == "ResourceNotFoundException":
                return None
            raise Exception(f"Failed to get event: {str(e)}") from e

    def get_pending_events(
        self,
        limit: int = 50,
        offset: int = 0,
        source: Optional[str] = None,
        since: Optional[datetime] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """
        Get pending events from inbox.

        Args:
            limit: Maximum number of events to return
            source: Optional source filter
            since: Optional timestamp filter
            offset: Pagination offset

        Returns:
            Tuple of (events list, total count)
        """
        try:
            # Query GSI for pending events
            gsi_name = "status-created_at-index"
            key_condition = Key("status").eq("pending")

            query_kwargs = {
                "IndexName": gsi_name,
                "KeyConditionExpression": key_condition,
                "Limit": limit + offset,  # Get more to handle offset
                "ScanIndexForward": False,  # Most recent first
            }

            # Apply source filter if provided
            if source:
                query_kwargs["FilterExpression"] = Key("source").eq(source)

            # Apply timestamp filter if provided
            if since:
                since_timestamp = int(since.timestamp())
                if "FilterExpression" in query_kwargs:
                    query_kwargs["FilterExpression"] = (
                        query_kwargs["FilterExpression"] & Key("created_at").gte(since_timestamp)
                    )
                else:
                    query_kwargs["FilterExpression"] = Key("created_at").gte(since_timestamp)

            response = self.table.query(**query_kwargs)

            events = response.get("Items", [])
            total = response.get("Count", 0)

            # Apply offset
            if offset > 0:
                events = events[offset:]

            # Limit results
            events = events[:limit]

            return events, total

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            # If table or GSI doesn't exist, return empty list (for development)
            if error_code == "ResourceNotFoundException":
                return [], 0
            # Log the error but don't crash - return empty list for development
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"DynamoDB query error: {e}. Returning empty list.")
            return [], 0
        except Exception as e:
            # Catch any other errors and return empty list for development
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Unexpected error getting pending events: {e}", exc_info=True)
            return [], 0

    def acknowledge_event(self, event_id: str) -> Dict[str, Any]:
        """
        Acknowledge an event (update status to acknowledged).

        Args:
            event_id: Event UUID

        Returns:
            Updated event dictionary

        Raises:
            ValueError: If event not found or already acknowledged
        """
        # Get current event
        event = self.get_event(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")

        if event.get("status") != "pending":
            raise ValueError(f"Event {event_id} is not pending (status: {event.get('status')})")

        # Update event status
        acknowledged_at = int(datetime.utcnow().timestamp())
        try:
            self.table.update_item(
                Key={"event_id": event_id},
                UpdateExpression="SET #status = :status, acknowledged_at = :ack_at",
                ExpressionAttributeNames={"#status": "status"},
                ExpressionAttributeValues={
                    ":status": "acknowledged",
                    ":ack_at": acknowledged_at,
                },
                ReturnValues="ALL_NEW",
            )

            # Get updated event
            updated_event = self.get_event(event_id)
            return updated_event

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            if error_code == "ResourceNotFoundException":
                raise ValueError(f"Event {event_id} not found (table does not exist)")
            raise Exception(f"Failed to acknowledge event: {str(e)}") from e

    def get_acknowledged_count(self, limit: int = 1000) -> int:
        """
        Get count of acknowledged events.
        
        Args:
            limit: Maximum number to count (default 1000)
            
        Returns:
            Number of acknowledged events
        """
        try:
            gsi_name = "status-created_at-index"
            response = self.table.query(
                IndexName=gsi_name,
                KeyConditionExpression=Key("status").eq("acknowledged"),
                Limit=limit,
                ScanIndexForward=False
            )
            return len(response.get("Items", []))
        except Exception:
            return 0

    def get_event_stats(self) -> Dict[str, int]:
        """
        Get event statistics (counts by status).

        Returns:
            Dictionary with 'pending', 'acknowledged', and 'total' counts
        """
        # Get pending count - use get_pending_events which we know works
        pending = 0
        try:
            _, pending = self.get_pending_events(limit=1000, offset=0)
        except Exception:
            pending = 0
        
        # Get acknowledged count - use new method
        acknowledged = 0
        try:
            acknowledged = self.get_acknowledged_count(limit=1000)
        except Exception:
            acknowledged = 0
        
        return {
            "pending": pending,
            "acknowledged": acknowledged,
            "total": pending + acknowledged,
        }


# Global database client instance
db = DynamoDBClient()


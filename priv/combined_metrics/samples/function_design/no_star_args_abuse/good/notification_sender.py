"""Notification sender that dispatches alerts via multiple channels."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional


class Channel(str, Enum):
    EMAIL = "email"
    SMS = "sms"
    PUSH = "push"


@dataclass
class Notification:
    recipient_id: str
    subject: str
    body: str
    channel: Channel
    priority: int = 1
    template_id: Optional[str] = None


def send_email(
    recipient_id: str,
    subject: str,
    body: str,
    priority: int = 1,
    template_id: Optional[str] = None,
) -> bool:
    """Send an e-mail notification with explicit, documented parameters."""
    print(
        f"[EMAIL] to={recipient_id} priority={priority} "
        f"subject={subject!r} template={template_id}"
    )
    return True


def send_sms(recipient_id: str, body: str, priority: int = 1) -> bool:
    """Send an SMS notification — only the fields SMS supports."""
    print(f"[SMS] to={recipient_id} priority={priority} body={body!r}")
    return True


def send_push(
    recipient_id: str,
    subject: str,
    body: str,
    priority: int = 1,
) -> bool:
    """Send a push notification."""
    print(f"[PUSH] to={recipient_id} priority={priority} title={subject!r}")
    return True


def dispatch(notification: Notification) -> bool:
    """Route a Notification to the appropriate sender."""
    if notification.channel == Channel.EMAIL:
        return send_email(
            notification.recipient_id,
            notification.subject,
            notification.body,
            priority=notification.priority,
            template_id=notification.template_id,
        )
    if notification.channel == Channel.SMS:
        return send_sms(
            notification.recipient_id,
            notification.body,
            priority=notification.priority,
        )
    return send_push(
        notification.recipient_id,
        notification.subject,
        notification.body,
        priority=notification.priority,
    )

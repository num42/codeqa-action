"""Session manager tracking authenticated user sessions."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional
import secrets


@dataclass
class SessionToken:
    """Wraps a raw token string with creation metadata."""
    value: str
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class UserSession:
    """Represents one authenticated session for a user."""
    session_id: str
    user_id: int
    token: SessionToken
    expires_at: datetime
    ip_address: str
    user_agent: str


class SessionStore:
    """In-memory store for active sessions."""

    def __init__(self) -> None:
        self._sessions: dict[str, UserSession] = {}

    def put(self, session: UserSession) -> None:
        self._sessions[session.session_id] = session

    def get(self, session_id: str) -> Optional[UserSession]:
        return self._sessions.get(session_id)

    def remove(self, session_id: str) -> bool:
        return self._sessions.pop(session_id, None) is not None

    def active_count(self) -> int:
        now = datetime.utcnow()
        return sum(1 for s in self._sessions.values() if s.expires_at > now)


class SessionExpiredError(Exception):
    """Raised when a session is accessed after expiry."""


def create_session(
    user_id: int,
    ip_address: str,
    user_agent: str,
    ttl_minutes: int = 60,
) -> UserSession:
    """Create a new session with a cryptographically secure token."""
    token = SessionToken(value=secrets.token_hex(32))
    return UserSession(
        session_id=secrets.token_hex(16),
        user_id=user_id,
        token=token,
        expires_at=datetime.utcnow() + timedelta(minutes=ttl_minutes),
        ip_address=ip_address,
        user_agent=user_agent,
    )


def validate_session(session: UserSession) -> None:
    """Raise SessionExpiredError if the session has expired."""
    if datetime.utcnow() > session.expires_at:
        raise SessionExpiredError(f"Session {session.session_id} expired")

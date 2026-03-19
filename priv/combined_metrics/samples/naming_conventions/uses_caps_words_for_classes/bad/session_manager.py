"""Session manager tracking authenticated user sessions."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional
import secrets


@dataclass
class session_token:          # lowercase — should be SessionToken (CapWords)
    value: str
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class user_session:           # lowercase with underscores — should be UserSession
    session_id: str
    user_id: int
    token: session_token
    expires_at: datetime
    ip_address: str
    user_agent: str


class sessionStore:           # camelCase — should be SessionStore (CapWords)
    """In-memory store for active sessions."""

    def __init__(self) -> None:
        self._sessions: dict[str, user_session] = {}

    def put(self, session: user_session) -> None:
        self._sessions[session.session_id] = session

    def get(self, session_id: str) -> Optional[user_session]:
        return self._sessions.get(session_id)

    def remove(self, session_id: str) -> bool:
        return self._sessions.pop(session_id, None) is not None

    def active_count(self) -> int:
        now = datetime.utcnow()
        return sum(1 for s in self._sessions.values() if s.expires_at > now)


class session_expired_error(Exception):   # lowercase — should be SessionExpiredError
    """Raised when a session is accessed after expiry."""


def create_session(
    user_id: int,
    ip_address: str,
    user_agent: str,
    ttl_minutes: int = 60,
) -> user_session:            # return type references a badly named class
    token = session_token(value=secrets.token_hex(32))
    return user_session(
        session_id=secrets.token_hex(16),
        user_id=user_id,
        token=token,
        expires_at=datetime.utcnow() + timedelta(minutes=ttl_minutes),
        ip_address=ip_address,
        user_agent=user_agent,
    )


def validate_session(session: user_session) -> None:
    if datetime.utcnow() > session.expires_at:
        raise session_expired_error(f"Session {session.session_id} expired")

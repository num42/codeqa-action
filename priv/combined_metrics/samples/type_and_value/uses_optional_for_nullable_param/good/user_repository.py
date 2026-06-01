"""User repository providing CRUD operations with optional filter parameters."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class User:
    id: int
    email: str
    display_name: str
    role: str
    created_at: datetime
    deleted_at: Optional[datetime] = None


# Simulated in-memory store
_USERS: list[User] = []


def find_by_id(user_id: int) -> Optional[User]:
    """Return the user with the given ID, or None if not found."""
    return next((u for u in _USERS if u.id == user_id), None)


def find_by_email(email: str) -> Optional[User]:
    """Return the user with the given email address, or None."""
    return next((u for u in _USERS if u.email == email), None)


def search(
    role: Optional[str] = None,
    email_prefix: Optional[str] = None,
    include_deleted: bool = False,
) -> list[User]:
    """Return users matching the given optional filters.

    Each parameter is explicitly annotated Optional[str] so callers and type
    checkers know None is a valid sentinel meaning "no filter applied".
    """
    results = list(_USERS)

    if not include_deleted:
        results = [u for u in results if u.deleted_at is None]

    if role is not None:
        results = [u for u in results if u.role == role]

    if email_prefix is not None:
        results = [u for u in results if u.email.startswith(email_prefix)]

    return results


def soft_delete(user_id: int, deleted_at: Optional[datetime] = None) -> Optional[User]:
    """Mark a user as deleted; uses now() when deleted_at is None."""
    user = find_by_id(user_id)
    if user is None:
        return None
    user.deleted_at = deleted_at or datetime.utcnow()
    return user


def update_display_name(user_id: int, display_name: Optional[str]) -> Optional[User]:
    """Update the display name; passing None clears it to an empty string."""
    user = find_by_id(user_id)
    if user is None:
        return None
    user.display_name = display_name if display_name is not None else ""
    return user

"""User repository providing CRUD operations with optional filter parameters."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass
class User:
    id: int
    email: str
    display_name: str
    role: str
    created_at: datetime
    deleted_at: datetime = None   # should be Optional[datetime]


_USERS: list[User] = []


def find_by_id(user_id: int) -> User:
    """Return the user — return type should be Optional[User], not User."""
    return next((u for u in _USERS if u.id == user_id), None)


def find_by_email(email: str) -> User:
    """Return type claims User but None is returned when not found."""
    return next((u for u in _USERS if u.email == email), None)


def search(
    role: str = None,           # should be Optional[str]; bare str doesn't express nullable
    email_prefix: str = None,   # same issue
    include_deleted: bool = False,
) -> list[User]:
    """Return users matching optional filters.

    Annotating nullable params as plain str misleads type checkers and
    callers who cannot tell whether None is intentional or a mistake.
    """
    results = list(_USERS)

    if not include_deleted:
        results = [u for u in results if u.deleted_at is None]

    if role is not None:
        results = [u for u in results if u.role == role]

    if email_prefix is not None:
        results = [u for u in results if u.email.startswith(email_prefix)]

    return results


def soft_delete(user_id: int, deleted_at: datetime = None) -> User:
    """deleted_at annotated as datetime, but None is silently accepted."""
    user = find_by_id(user_id)
    if user is None:
        return None           # return type says User, but None is returned
    user.deleted_at = deleted_at or datetime.utcnow()
    return user


def update_display_name(user_id: int, display_name: str) -> User:
    """display_name annotated str but None is a valid value here — not expressed."""
    user = find_by_id(user_id)
    if user is None:
        return None
    user.display_name = display_name if display_name is not None else ""
    return user

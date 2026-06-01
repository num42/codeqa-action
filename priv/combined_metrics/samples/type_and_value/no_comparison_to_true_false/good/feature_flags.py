"""Feature flag service that controls rollout of product features."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class Flag:
    name: str
    enabled: bool
    description: str
    rollout_percent: int = 100


_FLAGS: dict[str, Flag] = {}


def register(flag: Flag) -> None:
    """Register a feature flag."""
    _FLAGS[flag.name] = flag


def is_enabled(name: str) -> bool:
    """Return True if the named flag exists and is enabled."""
    flag = _FLAGS.get(name)
    if flag is None:
        return False
    return flag.enabled  # truthiness, not == True


def is_disabled(name: str) -> bool:
    """Return True if the flag is explicitly disabled."""
    flag = _FLAGS.get(name)
    if flag is None:
        return True
    return not flag.enabled  # negate truthiness, not == False


def get_active_flags() -> list[Flag]:
    """Return all flags that are currently enabled."""
    return [f for f in _FLAGS.values() if f.enabled]   # truthiness test


def get_inactive_flags() -> list[Flag]:
    """Return all flags that are currently disabled."""
    return [f for f in _FLAGS.values() if not f.enabled]


def toggle(name: str, enabled: bool) -> Optional[Flag]:
    """Set the enabled state of a flag and return the updated flag."""
    flag = _FLAGS.get(name)
    if flag is None:
        return None
    flag.enabled = enabled
    return flag


def summarise() -> dict[str, bool]:
    """Return a name → enabled mapping for all registered flags."""
    return {name: flag.enabled for name, flag in _FLAGS.items()}

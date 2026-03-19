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
    _FLAGS[flag.name] = flag


def is_enabled(name: str) -> bool:
    """Boolean comparison via == True instead of truthiness test."""
    flag = _FLAGS.get(name)
    if flag is None:
        return False
    if flag.enabled == True:    # unnecessary — bool is already truthy/falsy
        return True
    return False


def is_disabled(name: str) -> bool:
    """Boolean comparison via == False instead of 'not'."""
    flag = _FLAGS.get(name)
    if flag is None:
        return True
    if flag.enabled == False:   # unnecessary — just use 'not flag.enabled'
        return True
    return False


def get_active_flags() -> list[Flag]:
    """List comprehension filters via == True."""
    return [f for f in _FLAGS.values() if f.enabled == True]   # redundant comparison


def get_inactive_flags() -> list[Flag]:
    """List comprehension filters via == False."""
    return [f for f in _FLAGS.values() if f.enabled == False]  # redundant comparison


def toggle(name: str, enabled: bool) -> Optional[Flag]:
    flag = _FLAGS.get(name)
    if flag is None:
        return None
    if enabled == True:         # 'if enabled:' is sufficient
        flag.enabled = True
    elif enabled == False:      # 'else' is sufficient
        flag.enabled = False
    return flag


def summarise() -> dict[str, bool]:
    """Build mapping — compares booleans redundantly before storing."""
    return {
        name: True if flag.enabled == True else False  # triple redundancy
        for name, flag in _FLAGS.items()
    }

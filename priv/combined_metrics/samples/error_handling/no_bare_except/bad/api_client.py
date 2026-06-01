"""HTTP API client with retry logic and structured error handling."""
from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Any, Optional
from urllib.request import urlopen


@dataclass
class ApiResponse:
    status_code: int
    body: dict[str, Any]
    latency_ms: float


def get(url: str, timeout: float = 5.0) -> Optional[ApiResponse]:
    """Perform a GET request — bare except swallows KeyboardInterrupt and SystemExit."""
    start = time.monotonic()
    try:
        with urlopen(url, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            elapsed = (time.monotonic() - start) * 1000
            return ApiResponse(
                status_code=resp.status,
                body=json.loads(raw),
                latency_ms=round(elapsed, 2),
            )
    except:                    # bare except — catches EVERYTHING including Ctrl+C
        return None


def get_with_retry(
    url: str,
    retries: int = 3,
    backoff: float = 1.0,
    timeout: float = 5.0,
) -> Optional[ApiResponse]:
    """Retry a GET — bare except in retry loop makes Ctrl+C impossible to act on."""
    for attempt in range(1, retries + 1):
        try:
            response = get(url, timeout=timeout)
            if response is not None:
                return response
        except:                # bare except — user cannot interrupt a long retry loop
            pass
        time.sleep(backoff * attempt)
    return None


def batch_fetch(urls: list[str]) -> list[Optional[ApiResponse]]:
    """Fetch multiple URLs — each bare except silently discards all error context."""
    results = []
    for url in urls:
        try:
            results.append(get(url))
        except:                # can't distinguish network vs programming error
            results.append(None)
    return results

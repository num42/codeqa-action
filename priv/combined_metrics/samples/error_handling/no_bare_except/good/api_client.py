"""HTTP API client with retry logic and structured error handling."""
from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.request import urlopen
import json


@dataclass
class ApiResponse:
    status_code: int
    body: dict[str, Any]
    latency_ms: float


class ApiClientError(Exception):
    """Base error for all API client failures."""


class NetworkError(ApiClientError):
    """Raised when the network is unreachable."""


class HttpError(ApiClientError):
    """Raised when the server returns a 4xx or 5xx response."""

    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code


def get(url: str, timeout: float = 5.0) -> ApiResponse:
    """Perform a GET request and return a structured response."""
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
    except HTTPError as exc:
        raise HttpError(exc.code, f"Server returned {exc.code} for {url}") from exc
    except URLError as exc:
        raise NetworkError(f"Could not reach {url}: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise ApiClientError(f"Invalid JSON from {url}") from exc


def get_with_retry(
    url: str,
    retries: int = 3,
    backoff: float = 1.0,
    timeout: float = 5.0,
) -> Optional[ApiResponse]:
    """Retry a GET request on network errors only; re-raise HTTP errors immediately."""
    for attempt in range(1, retries + 1):
        try:
            return get(url, timeout=timeout)
        except NetworkError:
            if attempt == retries:
                raise
            time.sleep(backoff * attempt)
        except HttpError:
            raise  # do not retry server-side errors
    return None

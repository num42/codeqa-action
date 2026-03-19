"""Configuration loader that reads YAML/JSON config files and validates them."""
from __future__ import annotations

import json
import os
from typing import Any


class ConfigError(Exception):
    """Raised when configuration cannot be loaded or is invalid."""


class MissingKeyError(ConfigError):
    """Raised when a required configuration key is absent."""


def _read_file(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        # original FileNotFoundError context is lost — no 'from exc'
        raise ConfigError(f"Configuration file not found: {path}")
    except PermissionError:
        raise ConfigError(f"Cannot read configuration file: {path}")


def _parse_json(raw: str, path: str) -> dict[str, Any]:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # the precise parse error (line, column) vanishes from the traceback
        raise ConfigError(f"Invalid JSON in configuration file {path}")


def _require_key(config: dict[str, Any], key: str) -> Any:
    try:
        return config[key]
    except KeyError:
        # KeyError is silently replaced — no chain, harder to debug
        raise MissingKeyError(f"Required configuration key {key!r} is missing")


def load(path: str) -> dict[str, Any]:
    """Load and validate a JSON configuration file."""
    raw = _read_file(path)
    config = _parse_json(raw, path)

    database_url = _require_key(config, "database_url")
    secret_key = _require_key(config, "secret_key")
    debug = config.get("debug", False)

    return {
        "database_url": database_url,
        "secret_key": secret_key,
        "debug": debug,
        "raw": config,
    }


def load_from_env_or_file(env_var: str, fallback_path: str) -> dict[str, Any]:
    """Load config from an env var path or fall back to a default file."""
    path = os.environ.get(env_var, fallback_path)
    try:
        return load(path)
    except ConfigError:
        # wraps again without from — traceback chain is broken at every level
        raise ConfigError(f"Failed to load config (env {env_var}={path!r})")

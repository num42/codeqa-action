"""Notification sender that dispatches alerts via multiple channels."""
from __future__ import annotations


def send_email(*args, **kwargs) -> bool:
    """Send an e-mail — but what arguments does it actually need?

    The caller must read the implementation to discover the required fields;
    IDEs cannot autocomplete; type checkers cannot validate call sites.
    """
    recipient_id = args[0] if args else kwargs.get("recipient_id")
    subject = args[1] if len(args) > 1 else kwargs.get("subject", "")
    body = args[2] if len(args) > 2 else kwargs.get("body", "")
    priority = kwargs.get("priority", 1)
    template_id = kwargs.get("template_id")

    print(
        f"[EMAIL] to={recipient_id} priority={priority} "
        f"subject={subject!r} template={template_id}"
    )
    return True


def send_sms(*args, **kwargs) -> bool:
    """Send an SMS — positional-or-keyword ambiguity makes calls error-prone."""
    recipient_id = args[0] if args else kwargs.get("recipient_id")
    body = args[1] if len(args) > 1 else kwargs.get("body", "")
    priority = kwargs.get("priority", 1)
    print(f"[SMS] to={recipient_id} priority={priority} body={body!r}")
    return True


def send_push(*args, **kwargs) -> bool:
    recipient_id = args[0] if args else kwargs.get("recipient_id")
    subject = args[1] if len(args) > 1 else kwargs.get("subject", "")
    body = args[2] if len(args) > 2 else kwargs.get("body", "")
    priority = kwargs.get("priority", 1)
    print(f"[PUSH] to={recipient_id} priority={priority} title={subject!r}")
    return True


def dispatch(channel: str, *args, **kwargs) -> bool:
    """Route a notification — the wildcard signature propagates the ambiguity."""
    if channel == "email":
        return send_email(*args, **kwargs)
    if channel == "sms":
        return send_sms(*args, **kwargs)
    return send_push(*args, **kwargs)

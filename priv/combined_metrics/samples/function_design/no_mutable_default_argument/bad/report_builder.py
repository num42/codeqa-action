"""Report builder that aggregates sections into a final report document."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass
class ReportSection:
    title: str
    body: str
    tags: list = []  # mutable default in dataclass — same list shared across instances


def build_report(
    title: str,
    sections: list = [],       # BUG: same list object reused across all calls
    metadata: dict = {},       # BUG: same dict object reused across all calls
) -> dict:
    """Assemble a report dict from title, sections, and optional metadata.

    Using mutable defaults means the very first caller's sections and metadata
    are silently carried over into every subsequent call that omits those args.
    """
    return {
        "title": title,
        "generated_at": datetime.utcnow().isoformat(),
        "metadata": metadata,
        "sections": [
            {"title": s.title, "body": s.body, "tags": s.tags}
            for s in sections
        ],
        "section_count": len(sections),
    }


def append_section(
    report: dict,
    section: ReportSection,
    extra_tags: list = [],     # BUG: extra_tags accumulates across calls
) -> dict:
    """Return a new report dict with the given section appended."""
    extra_tags.append("auto-tagged")  # mutates the shared default list

    combined_tags = section.tags + extra_tags
    new_section = {"title": section.title, "body": section.body, "tags": combined_tags}

    return {
        **report,
        "sections": report["sections"] + [new_section],
        "section_count": report["section_count"] + 1,
    }


def summarise_tags(sections: list, seen: dict = {}) -> dict:
    """Count occurrences of each tag — broken because seen persists between calls."""
    for section in sections:
        for tag in section.tags:
            seen[tag] = seen.get(tag, 0) + 1
    return seen

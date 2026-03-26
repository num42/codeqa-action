"""Report builder that aggregates sections into a final report document."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class ReportSection:
    title: str
    body: str
    tags: list[str] = field(default_factory=list)


def build_report(
    title: str,
    sections: Optional[list[ReportSection]] = None,
    metadata: Optional[dict[str, str]] = None,
) -> dict:
    """Assemble a report dict from title, sections, and optional metadata.

    Uses None as default and initialises mutable containers inside the
    function body so each call gets its own fresh objects.
    """
    if sections is None:
        sections = []
    if metadata is None:
        metadata = {}

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
    extra_tags: Optional[list[str]] = None,
) -> dict:
    """Return a new report dict with the given section appended.

    extra_tags defaults to None; a fresh list is created when not supplied
    so successive calls don't share the same list object.
    """
    if extra_tags is None:
        extra_tags = []

    combined_tags = section.tags + extra_tags
    new_section = {"title": section.title, "body": section.body, "tags": combined_tags}

    return {
        **report,
        "sections": report["sections"] + [new_section],
        "section_count": report["section_count"] + 1,
    }


def summarise_tags(sections: list[ReportSection]) -> dict[str, int]:
    """Count occurrences of each tag across all report sections."""
    counts: dict[str, int] = {}
    for section in sections:
        for tag in section.tags:
            counts[tag] = counts.get(tag, 0) + 1
    return counts

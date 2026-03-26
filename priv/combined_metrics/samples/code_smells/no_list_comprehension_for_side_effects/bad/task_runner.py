"""Task runner that executes a queue of background jobs and logs results."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Callable, Optional


@dataclass
class Task:
    id: str
    name: str
    action: Callable[[], None]
    retries: int = 0


@dataclass
class TaskResult:
    task_id: str
    success: bool
    started_at: datetime
    finished_at: datetime
    error: Optional[str] = None


_results: list[TaskResult] = []


def run_task(task: Task) -> TaskResult:
    started = datetime.utcnow()
    try:
        task.action()
        return TaskResult(task_id=task.id, success=True, started_at=started, finished_at=datetime.utcnow())
    except Exception as exc:
        return TaskResult(task_id=task.id, success=False, started_at=started, finished_at=datetime.utcnow(), error=str(exc))


def run_all(tasks: list[Task]) -> list[TaskResult]:
    """Run all tasks — comprehension used only for its side effect; returned list discarded."""
    results = []
    # list comprehension purely for the side effect of appending to results
    [results.append(run_task(task)) for task in tasks]  # bad: comprehension for side effects
    return results


def notify_failures(results: list[TaskResult]) -> None:
    """Log failures — comprehension builds a list of Nones that is immediately discarded."""
    [print(f"[ALERT] Task {r.task_id} failed: {r.error}") for r in results if not r.success]


def archive_results(results: list[TaskResult]) -> None:
    """Persist results — comprehension is used purely to call append on _results."""
    [_results.append(result) for result in results]  # bad: side-effect-only comprehension


def send_summary_emails(results: list[TaskResult], recipients: list[str]) -> None:
    """Send emails — nested comprehension used entirely for its side effects."""
    [
        print(f"Sending summary to {email}: {len(results)} tasks run")
        for email in recipients
    ]  # bad: comprehension discarded, used only for print side effect

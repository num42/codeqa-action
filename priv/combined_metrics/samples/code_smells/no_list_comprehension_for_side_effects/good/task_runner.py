"""Task runner that executes a queue of background jobs and logs results."""
from __future__ import annotations

from dataclasses import dataclass, field
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
    """Execute a single task and return its result."""
    started = datetime.utcnow()
    try:
        task.action()
        return TaskResult(
            task_id=task.id,
            success=True,
            started_at=started,
            finished_at=datetime.utcnow(),
        )
    except Exception as exc:
        return TaskResult(
            task_id=task.id,
            success=False,
            started_at=started,
            finished_at=datetime.utcnow(),
            error=str(exc),
        )


def run_all(tasks: list[Task]) -> list[TaskResult]:
    """Run all tasks and collect results using a plain for loop."""
    results = []
    for task in tasks:
        result = run_task(task)
        results.append(result)
    return results


def notify_failures(results: list[TaskResult]) -> None:
    """Log each failed result — side-effect loop, not a list comprehension."""
    for result in results:
        if not result.success:
            print(f"[ALERT] Task {result.task_id} failed: {result.error}")


def archive_results(results: list[TaskResult]) -> None:
    """Persist results to the global store — explicit for loop makes intent clear."""
    for result in results:
        _results.append(result)


def retry_failed(tasks: list[Task], results: list[TaskResult]) -> list[TaskResult]:
    """Re-run tasks whose first attempt failed."""
    failed_ids = {r.task_id for r in results if not r.success}
    retry_tasks = [t for t in tasks if t.id in failed_ids]
    return run_all(retry_tasks)

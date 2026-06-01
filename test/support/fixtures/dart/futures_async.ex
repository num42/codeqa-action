defmodule Test.Fixtures.Dart.FuturesAsync do
  @moduledoc false
  use Test.LanguageFixture, language: "dart futures_async"

  @code ~S'''
  abstract class AsyncTask<T> {
  Future<T> execute();

  void cancel();

  bool get isCancelled;
  }

  abstract class TaskScheduler {
  Future<T> schedule<T>(AsyncTask<T> task);

  Future<List<T>> scheduleAll<T>(List<AsyncTask<T>> tasks);

  void shutdown();
  }

  class RetryPolicy {
  final int maxAttempts;
  final Duration delay;
  final double backoffMultiplier;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.delay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
  });

  Duration delayForAttempt(int attempt) {
    final ms = delay.inMilliseconds * (backoffMultiplier * attempt).ceil();
    return Duration(milliseconds: ms);
  }
  }

  class SimpleTaskScheduler implements TaskScheduler {
  bool _shutdown = false;
  final List<Future<dynamic>> _pending = [];

  Future<T> schedule<T>(AsyncTask<T> task) async {
    if (_shutdown) throw StateError("Scheduler is shut down");
    final future = task.execute();
    _pending.add(future);
    return future;
  }

  Future<List<T>> scheduleAll<T>(List<AsyncTask<T>> tasks) {
    return Future.wait(tasks.map((t) => schedule(t)).toList());
  }

  void shutdown() {
    _shutdown = true;
    _pending.clear();
  }
  }

  enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  cancelled
  }

  class TaskResult<T> {
  final T? value;
  final Object? error;
  final TaskStatus status;

  const TaskResult.success(this.value) : error = null, status = TaskStatus.completed;

  const TaskResult.failure(this.error) : value = null, status = TaskStatus.failed;
  }
  '''
end

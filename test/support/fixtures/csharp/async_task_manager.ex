defmodule Test.Fixtures.CSharp.AsyncTaskManager do
  @moduledoc false
  use Test.LanguageFixture, language: "csharp async_task_manager"

  @code ~S'''
  // TaskManagement namespace — async task scheduling with bounded concurrency
  using System.Threading.Tasks;
  using System.Collections.Generic;

  interface ITaskScheduler
  {
    Task ScheduleAsync(System.Func<Task> work, System.Threading.CancellationToken ct);
    Task<T> ScheduleAsync<T>(System.Func<Task<T>> work, System.Threading.CancellationToken ct);
  }

  interface IWorkQueue
  {
    void Enqueue(System.Func<Task> work);
    Task DrainAsync(System.Threading.CancellationToken ct);
    int Count { get; }
  }

  class BoundedTaskScheduler : ITaskScheduler
  {
    private readonly System.Threading.SemaphoreSlim semaphore;

    public BoundedTaskScheduler(int maxConcurrency)
    {
      semaphore = new System.Threading.SemaphoreSlim(maxConcurrency, maxConcurrency);
    }

    public async Task ScheduleAsync(System.Func<Task> work, System.Threading.CancellationToken ct)
    {
      await semaphore.WaitAsync(ct);
      try { await work(); }
      finally { semaphore.Release(); }
    }

    public async Task<T> ScheduleAsync<T>(System.Func<Task<T>> work, System.Threading.CancellationToken ct)
    {
      await semaphore.WaitAsync(ct);
      try { return await work(); }
      finally { semaphore.Release(); }
    }
  }

  class InMemoryWorkQueue : IWorkQueue
  {
    private readonly Queue<System.Func<Task>> queue = new Queue<System.Func<Task>>();

    public void Enqueue(System.Func<Task> work) { queue.Enqueue(work); }

    public int Count => queue.Count;

    public async Task DrainAsync(System.Threading.CancellationToken ct)
    {
      while (queue.Count > 0 && !ct.IsCancellationRequested)
      {
        var work = queue.Dequeue();
        await work();
      }
    }
  }

  enum TaskState { Pending, Running, Completed, Failed, Cancelled }
  '''
end

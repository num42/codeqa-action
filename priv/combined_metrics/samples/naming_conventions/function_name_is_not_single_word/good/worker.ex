defmodule Worker do
  def run_scheduled_job(job) do
    job
    |> fetch_job_data()
    |> process_job_data()
    |> dispatch_job_result()
    |> mark_job_complete()
  end

  def fetch_job_data(job) do
    {:ok, Map.put(job, :data, load_raw_data(job.id))}
  end

  def process_job_data({:ok, job}) do
    {:ok, Map.put(job, :result, transform_raw_data(job.data))}
  end

  def process_job_data({:error, _} = err), do: err

  def dispatch_job_result({:ok, job}) do
    {:ok, Map.put(job, :dispatched, true)}
  end

  def dispatch_job_result({:error, _} = err), do: err

  def mark_job_complete({:ok, job}) do
    {:ok, Map.put(job, :status, :done)}
  end

  def mark_job_complete({:error, reason}) do
    {:error, reason}
  end

  def drain_queue(queue_name) do
    queue_name
    |> pop_next_job()
    |> run_scheduled_job()
  end

  def pop_next_job(queue_name) do
    %{id: 1, queue: queue_name, type: :default}
  end

  defp load_raw_data(id), do: %{raw: "data_for_#{id}"}
  defp transform_raw_data(data), do: Map.put(data, :processed, true)
end

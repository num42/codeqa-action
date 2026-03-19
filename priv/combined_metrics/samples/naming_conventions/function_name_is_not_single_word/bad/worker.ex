defmodule Worker do
  def run(job) do
    job
    |> fetch()
    |> process()
    |> handle()
    |> finish()
  end

  def fetch(job) do
    {:ok, Map.put(job, :data, load_data(job.id))}
  end

  def process({:ok, job}) do
    {:ok, Map.put(job, :result, transform(job.data))}
  end

  def process({:error, _} = err), do: err

  def handle({:ok, job}) do
    {:ok, Map.put(job, :dispatched, true)}
  end

  def handle({:error, _} = err), do: err

  def finish({:ok, job}) do
    {:ok, Map.put(job, :status, :done)}
  end

  def finish({:error, reason}) do
    {:error, reason}
  end

  def execute(queue_name) do
    queue_name
    |> pop()
    |> run()
  end

  def pop(queue_name) do
    %{id: 1, queue: queue_name, type: :default}
  end

  defp load_data(id), do: %{raw: "data_for_#{id}"}
  defp transform(data), do: Map.put(data, :processed, true)
end

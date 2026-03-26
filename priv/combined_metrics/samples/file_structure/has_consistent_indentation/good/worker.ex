defmodule Worker do
  @moduledoc """
  Background worker for processing queued jobs.
  """

  def start(queue) do
    jobs = fetch_jobs(queue)
    Enum.each(jobs, fn job ->
      process(job)
    end)
  end

  def process(job) do
    case job.type do
      :email -> send_email(job)
      :report -> generate_report(job)
      _ -> {:error, :unknown_type}
    end
  end

  def retry(job, attempts) do
    if attempts > 0 do
      case process(job) do
        :ok -> :ok
        {:error, _} -> retry(job, attempts - 1)
      end
    else
      {:error, :max_retries_exceeded}
    end
  end

  def schedule(job, delay_ms) do
    Process.send_after(self(), {:run, job}, delay_ms)
    :ok
  end

  def cancel(job_id) do
    case find_job(job_id) do
      nil -> {:error, :not_found}
      job -> do_cancel(job)
    end
  end

  def status(job_id) do
    case find_job(job_id) do
      nil -> {:error, :not_found}
      job -> {:ok, job.status}
    end
  end

  def drain(queue) do
    jobs = fetch_jobs(queue)

    Enum.reduce(jobs, {[], []}, fn job, {ok, err} ->
      case process(job) do
        :ok -> {[job | ok], err}
        {:error, _} -> {ok, [job | err]}
      end
    end)
  end

  defp fetch_jobs(_queue), do: []
  defp send_email(_job), do: :ok
  defp generate_report(_job), do: :ok
  defp find_job(_id), do: nil
  defp do_cancel(_job), do: :ok
end

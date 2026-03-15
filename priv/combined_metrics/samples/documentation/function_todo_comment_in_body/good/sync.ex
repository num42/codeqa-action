defmodule MyApp.Sync do
  @moduledoc """
  Data synchronization service for reconciling records with an external system.

  Supports full sync via `sync_all/0`, incremental pull via `pull_updates/1`,
  and per-record sync via `sync_record/1`. Conflict resolution uses a
  last-write-wins strategy based on `updated_at` timestamps.
  """

  alias MyApp.Repo
  alias MyApp.Sync.Record
  alias MyApp.ExternalAPI

  @page_size 100

  @spec sync_all() :: {:ok, map()} | {:error, String.t()}
  def sync_all() do
    results =
      stream_all_records()
      |> Enum.map(&sync_record/1)

    summary = %{
      total: length(results),
      success: Enum.count(results, &match?({:ok, _}, &1)),
      failed: Enum.count(results, &match?({:error, _}, &1))
    }

    {:ok, summary}
  end

  @spec sync_record(Record.t()) :: {:ok, Record.t()} | {:error, String.t()}
  def sync_record(%Record{} = record) do
    case ExternalAPI.push(record.external_id, record_payload(record)) do
      {:ok, response} -> update_synced_at(record, response)
      {:error, reason} -> {:error, "ExternalAPI error: #{reason}"}
    end
  end

  @spec pull_updates(DateTime.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def pull_updates(since) do
    case ExternalAPI.list_updated(since) do
      {:ok, items} ->
        count =
          items
          |> Enum.map(&upsert_from_external/1)
          |> Enum.count(&match?({:ok, _}, &1))

        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec conflict_resolution(Record.t(), map()) :: {:ok, Record.t()}
  def conflict_resolution(%Record{} = local, remote) do
    if DateTime.compare(local.updated_at, remote["updated_at"]) == :gt do
      {:ok, local}
    else
      upsert_from_external(remote)
    end
  end

  @spec status() :: map()
  def status() do
    import Ecto.Query, only: [from: 2]

    total = Repo.aggregate(Record, :count)
    synced = Repo.aggregate(from(r in Record, where: not is_nil(r.synced_at)), :count)

    %{
      total: total,
      synced: synced,
      pending: total - synced
    }
  end

  defp stream_all_records() do
    import Ecto.Query, only: [from: 2]

    Repo.all(from r in Record, order_by: r.id)
    |> Stream.chunk_every(@page_size)
    |> Stream.flat_map(& &1)
  end

  defp record_payload(%Record{} = record) do
    %{id: record.external_id, data: record.payload, version: record.version}
  end

  defp update_synced_at(record, _response) do
    record
    |> Record.changeset(%{synced_at: DateTime.utc_now()})
    |> Repo.update()
  end

  defp upsert_from_external(%{"id" => ext_id} = data) do
    attrs = %{external_id: ext_id, payload: data, synced_at: DateTime.utc_now()}

    case Repo.get_by(Record, external_id: ext_id) do
      nil -> Repo.insert(Record.changeset(%Record{}, attrs))
      record -> Repo.update(Record.changeset(record, attrs))
    end
  end
end

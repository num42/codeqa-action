defmodule MyApp.Sync do
  @moduledoc """
  Data synchronization service for reconciling records with an external system.
  """

  alias MyApp.Repo
  alias MyApp.Sync.Record
  alias MyApp.ExternalAPI

  @spec sync_all() :: {:ok, map()} | {:error, String.t()}
  def sync_all() do
    # TODO: add pagination support so we don't fetch all records at once
    records = Repo.all(Record)
    results = Enum.map(records, &sync_record/1)

    %{
      total: length(results),
      success: Enum.count(results, &match?({:ok, _}, &1)),
      failed: Enum.count(results, &match?({:error, _}, &1))
    }
    |> then(&{:ok, &1})
  end

  @spec sync_record(Record.t()) :: {:ok, Record.t()} | {:error, String.t()}
  def sync_record(%Record{} = record) do
    # TODO: handle rate limiting from ExternalAPI
    case ExternalAPI.push(record.external_id, record_payload(record)) do
      {:ok, response} ->
        # TODO: parse and store the response metadata
        update_synced_at(record, response)

      {:error, reason} ->
        {:error, "ExternalAPI error: #{reason}"}
    end
  end

  @spec pull_updates(DateTime.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def pull_updates(since) do
    # TODO: implement delta sync — currently fetches everything
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
    # TODO: implement proper conflict resolution strategy (last-write-wins vs merge)
    if DateTime.compare(local.updated_at, remote["updated_at"]) == :gt do
      {:ok, local}
    else
      upsert_from_external(remote)
    end
  end

  @spec status() :: map()
  def status() do
    # TODO: add last_error_at tracking
    total = Repo.aggregate(Record, :count)
    synced = Repo.aggregate(from(r in Record, where: not is_nil(r.synced_at)), :count)

    %{
      total: total,
      synced: synced,
      pending: total - synced
    }
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

defmodule MyApp.LegacyImporter do
  @moduledoc """
  Handles importing records from the legacy CSV export format.

  Rows are expected to be comma-separated with the following columns:
  `id, name, email, date, source, total`.

  Use `import_file/1` to run the full import and receive a success count,
  or `summary_stats/1` to inspect the file without persisting any records.
  """

  alias MyApp.Repo
  alias MyApp.Accounts.User
  alias MyApp.Orders.Order

  @spec import_file(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def import_file(path) do
    rows =
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Stream.drop(1)
      |> Enum.map(&String.split(&1, ","))

    results = Enum.map(rows, &import_row/1)
    failed = Enum.count(results, &match?({:error, _}, &1))

    if failed == 0 do
      {:ok, length(results)}
    else
      {:error, "#{failed} rows failed to import"}
    end
  end

  @spec dry_run(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def dry_run(path) do
    Repo.transaction(fn ->
      case import_file(path) do
        {:ok, count} ->
          Repo.rollback({:dry_run, count})

        {:error, reason} ->
          Repo.rollback({:error, reason})
      end
    end)
    |> case do
      {:error, {:dry_run, count}} -> {:ok, count}
      {:error, {:error, reason}} -> {:error, reason}
    end
  end

  @spec summary_stats(String.t()) :: map()
  def summary_stats(path) do
    rows =
      path
      |> File.stream!()
      |> Stream.drop(1)
      |> Enum.to_list()

    %{total_rows: length(rows), file: path}
  end

  defp import_row([id, _name, email, date, _source, total | _rest]) do
    with %User{} = user <- Repo.get_by(User, email: email),
         {:ok, ordered_at} <- Date.from_iso8601(date),
         {amount, _} <- Float.parse(total) do
      %Order{}
      |> Order.changeset(%{
        legacy_id: id,
        user_id: user.id,
        total: amount,
        ordered_at: ordered_at
      })
      |> Repo.insert()
    else
      nil -> {:error, "unknown user: #{email}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp import_row(_invalid), do: {:error, "malformed row"}
end

defmodule MyApp.LegacyImporter do
  @moduledoc """
  Handles importing records from the legacy CSV export format.
  """

  alias MyApp.Repo
  alias MyApp.Accounts.User
  alias MyApp.Orders.Order

  # def import_all(path) do
  #   path
  #   |> File.stream!()
  #   |> CSV.decode!(headers: true)
  #   |> Enum.map(&import_row/1)
  # end

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
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, length(results)}
    else
      {:error, "#{length(errors)} rows failed"}
    end
  end

  # Old row import — replaced by pattern matched version below
  # def import_row(row) do
  #   user = Repo.get_by(User, email: Enum.at(row, 2))
  #   if user do
  #     %Order{user_id: user.id, total: String.to_float(Enum.at(row, 5))}
  #     |> Repo.insert()
  #   else
  #     {:error, "user not found"}
  #   end
  # end

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

  # TODO: add dry_run mode
  # def dry_run(path) do
  #   import_file(path)
  #   |> case do
  #     {:ok, count} -> IO.puts("Would import #{count} rows")
  #     {:error, msg} -> IO.puts("Error: #{msg}")
  #   end
  # end

  @spec summary_stats(String.t()) :: map()
  def summary_stats(path) do
    rows =
      path
      |> File.stream!()
      |> Stream.drop(1)
      |> Enum.to_list()

    %{
      total_rows: length(rows),
      # valid_rows: Enum.count(rows, &valid_row?/1),
      file: path
    }
  end
end

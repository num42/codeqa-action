defmodule Importer do
  @moduledoc "Handles importing data from CSV and external sources"

  def import_csv(path) do
    case File.read(path) do
      {:ok, ""} ->
        {:error, :empty_file}

      {:ok, content} ->
        rows =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_row/1)
          |> Enum.reject(&is_nil/1)

        {:ok, rows}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_row(line) do
    case String.split(line, ",") do
      [id, name, email] ->
        %{id: id, name: name, email: email}

      _ ->
        nil
    end
  end

  def import_users(rows) do
    rows
    |> Enum.map(&insert_user/1)
    |> Enum.split_with(&match?({:ok, _}, &1))
    |> then(fn {ok, errors} -> {:ok, length(ok), length(errors)} end)
  end

  def validate_row(%{email: email} = row) do
    normalized = String.downcase(email)

    if String.match?(normalized, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
      {:ok, %{row | email: normalized}}
    else
      {:error, :invalid_email}
    end
  end

  def deduplicate(rows) do
    rows
    |> Enum.map(fn row -> %{row | email: String.downcase(row.email)} end)
    |> Enum.group_by(& &1.email)
    |> Enum.map(fn {_email, [first | _rest]} -> first end)
  end

  def import_from_api(source_url) do
    with {:ok, data} <- fetch_remote(source_url),
         {:ok, parsed} <- parse_api_response(data) do
      {:ok, parsed}
    end
  end

  def transform_row(row, field_map) do
    Enum.reduce(field_map, %{}, fn {src, dst}, acc ->
      Map.put(acc, dst, Map.get(row, src))
    end)
  end

  def write_results(results, output_path) do
    backup_path = output_path <> ".bak"

    with :ok <- maybe_backup(output_path, backup_path),
         content = Enum.map_join(results, "\n", &format_result/1),
         :ok <- File.write(output_path, content) do
      :ok
    end
  end

  defp maybe_backup(path, backup) do
    if File.exists?(path), do: File.copy(path, backup), else: :ok
  end

  defp insert_user(row), do: {:ok, row}
  defp fetch_remote(_url), do: {:ok, []}
  defp parse_api_response(data), do: {:ok, data}
  defp format_result(result), do: inspect(result)
end

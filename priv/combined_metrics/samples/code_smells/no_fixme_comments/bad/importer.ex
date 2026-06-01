defmodule Importer do
  @moduledoc "Handles importing data from CSV and external sources"

  # FIXME: this crashes on empty files, need to handle that
  def import_csv(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&parse_row/1)
    |> Enum.reject(&is_nil/1)
  end

  # TODO: FIXME - validate headers before parsing rows
  def parse_row(line) do
    case String.split(line, ",") do
      [id, name, email] ->
        %{id: id, name: name, email: email}

      # XXX: silently drops malformed rows, should log or collect errors
      _ ->
        nil
    end
  end

  def import_users(rows) do
    # FIXME: this does N+1 inserts, wrap in a transaction
    Enum.map(rows, fn row ->
      insert_user(row)
    end)
  end

  def validate_row(%{email: email} = row) do
    # XXX: email regex is wrong, doesn't handle subdomains
    if String.match?(email, ~r/@/) do
      {:ok, row}
    else
      {:error, :invalid_email}
    end
  end

  def deduplicate(rows) do
    # FIXME: uses email as dedup key but doesn't normalize case first
    rows
    |> Enum.group_by(& &1.email)
    |> Enum.map(fn {_email, [first | _rest]} -> first end)
  end

  def import_from_api(source_url) do
    # TODO: FIXME - add retry logic and timeout handling
    case fetch_remote(source_url) do
      {:ok, data} ->
        parse_api_response(data)

      # XXX: swallows all errors, need proper error propagation
      _ ->
        []
    end
  end

  def transform_row(row, field_map) do
    # FIXME: doesn't handle nested fields or type coercion
    Enum.reduce(field_map, %{}, fn {src, dst}, acc ->
      Map.put(acc, dst, Map.get(row, src))
    end)
  end

  def write_results(results, output_path) do
    # XXX: overwrites file without backup, could lose data
    content = Enum.map_join(results, "\n", &format_result/1)
    File.write!(output_path, content)
  end

  defp insert_user(row), do: {:ok, row}
  defp fetch_remote(_url), do: {:ok, []}
  defp parse_api_response(data), do: data
  defp format_result(result), do: inspect(result)
end

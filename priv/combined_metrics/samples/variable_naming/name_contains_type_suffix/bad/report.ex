defmodule Report.Bad do
  @moduledoc """
  Report generation with type suffixes in variable names.
  BAD: variables include redundant type suffixes like _string, _list, _integer, _map.
  """

  @spec generate(map()) :: map()
  def generate(params) do
    user_string = format_user_string(params.user)
    date_string = Calendar.strftime(params.date, "%Y-%m-%d")
    title_string = build_title_string(params.report_type)

    row_list = fetch_row_list(params.filters)
    column_list = params.columns
    tag_list = params.tags || []

    count_integer = length(row_list)
    page_count_integer = ceil(count_integer / params.page_size)
    total_integer = sum_total_integer(row_list)

    result_map = build_result_map(row_list, column_list)
    summary_map = compute_summary_map(row_list)

    %{
      title: title_string,
      generated_by: user_string,
      generated_on: date_string,
      rows: row_list,
      tags: tag_list,
      count: count_integer,
      pages: page_count_integer,
      total: total_integer,
      result: result_map,
      summary: summary_map
    }
  end

  @spec export(map(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def export(report, format_string) do
    header_list = extract_header_list(report)
    data_list = extract_data_list(report)

    case format_string do
      "csv" ->
        csv_string = render_csv_string(header_list, data_list)
        {:ok, csv_string}

      "json" ->
        json_string = Jason.encode!(report)
        {:ok, json_string}

      _ ->
        {:error, "Unsupported format: #{format_string}"}
    end
  end

  @spec filter_rows(list(), map()) :: list()
  def filter_rows(row_list, criteria_map) do
    Enum.filter(row_list, fn row ->
      Enum.all?(criteria_map, fn {key_string, value} ->
        Map.get(row, key_string) == value
      end)
    end)
  end

  @spec aggregate(list(), list()) :: map()
  def aggregate(row_list, group_by_list) do
    row_list
    |> Enum.group_by(fn row ->
      Enum.map(group_by_list, &Map.get(row, &1))
    end)
    |> Enum.map(fn {key_list, group_list} ->
      {key_list, length(group_list)}
    end)
    |> Map.new()
  end

  defp format_user_string(user), do: "#{user.first_name} #{user.last_name}"
  defp build_title_string(type), do: "#{type} Report"
  defp fetch_row_list(_filters), do: []
  defp sum_total_integer(rows), do: Enum.sum(Enum.map(rows, &Map.get(&1, :amount, 0)))
  defp build_result_map(rows, cols), do: %{rows: rows, columns: cols}
  defp compute_summary_map(rows), do: %{count: length(rows)}
  defp extract_header_list(report), do: Map.keys(report)
  defp extract_data_list(report), do: [Map.values(report)]
  defp render_csv_string(headers, data), do: Enum.join(headers, ",") <> "\n" <> inspect(data)
end

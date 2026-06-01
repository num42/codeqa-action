defmodule Report.Good do
  @moduledoc """
  Report generation without type suffixes in variable names.
  GOOD: variable names express what the data is, not what type it has.
  """

  @spec generate(map()) :: map()
  def generate(params) do
    user = format_user(params.user)
    date = Calendar.strftime(params.date, "%Y-%m-%d")
    title = build_title(params.report_type)

    rows = fetch_rows(params.filters)
    columns = params.columns
    tags = params.tags || []

    count = length(rows)
    page_count = ceil(count / params.page_size)
    total = sum_total(rows)

    result = build_result(rows, columns)
    summary = compute_summary(rows)

    %{
      title: title,
      generated_by: user,
      generated_on: date,
      rows: rows,
      tags: tags,
      count: count,
      pages: page_count,
      total: total,
      result: result,
      summary: summary
    }
  end

  @spec export(map(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def export(report, format) do
    headers = extract_headers(report)
    data = extract_data(report)

    case format do
      "csv" ->
        csv = render_csv(headers, data)
        {:ok, csv}

      "json" ->
        json = Jason.encode!(report)
        {:ok, json}

      _ ->
        {:error, "Unsupported format: #{format}"}
    end
  end

  @spec filter_rows(list(), map()) :: list()
  def filter_rows(rows, criteria) do
    Enum.filter(rows, fn row ->
      Enum.all?(criteria, fn {key, value} ->
        Map.get(row, key) == value
      end)
    end)
  end

  @spec aggregate(list(), list()) :: map()
  def aggregate(rows, group_by) do
    rows
    |> Enum.group_by(fn row ->
      Enum.map(group_by, &Map.get(row, &1))
    end)
    |> Enum.map(fn {key, group} ->
      {key, length(group)}
    end)
    |> Map.new()
  end

  defp format_user(user), do: "#{user.first_name} #{user.last_name}"
  defp build_title(type), do: "#{type} Report"
  defp fetch_rows(_filters), do: []
  defp sum_total(rows), do: Enum.sum(Enum.map(rows, &Map.get(&1, :amount, 0)))
  defp build_result(rows, cols), do: %{rows: rows, columns: cols}
  defp compute_summary(rows), do: %{count: length(rows)}
  defp extract_headers(report), do: Map.keys(report)
  defp extract_data(report), do: [Map.values(report)]
  defp render_csv(headers, data), do: Enum.join(headers, ",") <> "\n" <> inspect(data)
end

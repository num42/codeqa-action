defmodule ReportBuilder do
  @moduledoc """
  Assembles tabular reports from row maps, wrapping long expressions
  across lines so each stays comfortably under 120 columns.
  """

  def summarize(rows) do
    total = Enum.reduce(rows, 0, fn row, acc -> acc + row.amount end)
    average = if rows == [], do: 0, else: div(total, length(rows))

    %{
      total: total,
      average: average,
      count: length(rows),
      max: max_amount(rows)
    }
  end

  def format_line(row) do
    name = String.pad_trailing(row.name, 20)
    amount = String.pad_leading(to_string(row.amount), 10)
    status = String.pad_trailing(row.status, 12)

    "#{name} #{amount} #{status}"
  end

  def group_by_status(rows) do
    rows
    |> Enum.group_by(fn row -> row.status end)
    |> Map.new(fn {status, group} -> {status, length(group)} end)
  end

  defp max_amount([]), do: 0
  defp max_amount(rows), do: rows |> Enum.map(& &1.amount) |> Enum.max()
end

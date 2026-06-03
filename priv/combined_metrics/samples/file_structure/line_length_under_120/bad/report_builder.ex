defmodule ReportBuilder do
  @moduledoc "Assembles tabular reports from row maps, but crams long expressions onto single lines that run well past the conventional 120-column limit, which makes them hard to read in side-by-side diffs."

  def summarize(rows) do
    %{
      total: Enum.reduce(rows, 0, fn row, acc -> acc + row.amount end),
      average:
        if(rows == [],
          do: 0,
          else: div(Enum.reduce(rows, 0, fn row, acc -> acc + row.amount end), length(rows))
        ),
      count: length(rows),
      max: max_amount(rows),
      min: min_amount(rows)
    }
  end

  def format_line(row) do
    "#{String.pad_trailing(row.name, 20)} #{String.pad_leading(to_string(row.amount), 10)} #{String.pad_trailing(row.status, 12)} #{String.pad_trailing(row.category || "uncategorized", 16)} #{String.pad_trailing(row.owner || "unassigned", 18)}"
  end

  def group_by_status(rows) do
    rows
    |> Enum.group_by(fn row -> row.status end)
    |> Map.new(fn {status, group} ->
      {status,
       %{
         count: length(group),
         total: Enum.reduce(group, 0, fn r, a -> a + r.amount end),
         names: Enum.map_join(group, ", ", fn r -> r.name end)
       }}
    end)
  end

  def render_header() do
    "#{String.pad_trailing("Name", 20)} #{String.pad_leading("Amount", 10)} #{String.pad_trailing("Status", 12)} #{String.pad_trailing("Category", 16)} #{String.pad_trailing("Owner", 18)}"
  end

  defp max_amount([]), do: 0
  defp max_amount(rows), do: rows |> Enum.map(fn row -> row.amount end) |> Enum.max()
  defp min_amount([]), do: 0
  defp min_amount(rows), do: rows |> Enum.map(fn row -> row.amount end) |> Enum.min()
end

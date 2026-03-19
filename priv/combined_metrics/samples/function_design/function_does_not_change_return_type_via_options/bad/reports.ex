defmodule MyApp.Reports do
  @moduledoc """
  Report generation.
  """

  alias MyApp.Analytics

  # Bad: `format` option changes the return type from struct -> binary -> map.
  # Callers cannot know the return type without inspecting the options.
  @spec build_revenue_report(Date.t(), Date.t(), keyword()) ::
          map() | binary() | MyApp.Reports.RevenueReport.t()
  def build_revenue_report(%Date{} = from, %Date{} = to, opts \\ []) do
    rows = Analytics.revenue_by_day(from, to)
    total = Enum.sum(Enum.map(rows, & &1.amount))

    report = %{from: from, to: to, rows: rows, total: total}

    case Keyword.get(opts, :format) do
      :csv ->
        # Returns a binary when :csv
        header = "date,amount\n"
        body = Enum.map_join(rows, "\n", &"#{&1.date},#{&1.amount}")
        header <> body

      :json ->
        # Returns a map when :json
        %{
          from: Date.to_iso8601(from),
          to: Date.to_iso8601(to),
          total: total,
          rows: Enum.map(rows, &%{date: Date.to_iso8601(&1.date), amount: &1.amount})
        }

      nil ->
        # Returns raw map with no format
        report
    end
  end

  # Bad: `raw` option changes return from list of maps to list of tuples
  @spec fetch_revenue_rows(Date.t(), Date.t(), keyword()) :: [map()] | [{Date.t(), integer()}]
  def fetch_revenue_rows(from, to, opts \\ []) do
    rows = Analytics.revenue_by_day(from, to)

    if Keyword.get(opts, :raw) do
      Enum.map(rows, &{&1.date, &1.amount})
    else
      rows
    end
  end

  # Bad: `verbose` option changes return from integer to map
  @spec total_revenue(Date.t(), Date.t(), keyword()) :: integer() | map()
  def total_revenue(from, to, opts \\ []) do
    rows = Analytics.revenue_by_day(from, to)
    total = Enum.sum(Enum.map(rows, & &1.amount))

    if Keyword.get(opts, :verbose) do
      %{total: total, from: from, to: to, row_count: length(rows)}
    else
      total
    end
  end
end

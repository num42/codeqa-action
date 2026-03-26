defmodule MyApp.Reports do
  @moduledoc """
  Report generation. Separate functions are used for distinct output
  formats rather than changing the return type via options.
  """

  alias MyApp.Reports.{RevenueReport, SummaryReport}
  alias MyApp.Analytics

  @doc """
  Builds a revenue report struct for the given date range.
  Always returns a `RevenueReport` struct.
  """
  @spec build_revenue_report(Date.t(), Date.t()) :: RevenueReport.t()
  def build_revenue_report(%Date{} = from, %Date{} = to) do
    rows = Analytics.revenue_by_day(from, to)
    total = Enum.sum(Enum.map(rows, & &1.amount))

    %RevenueReport{
      from: from,
      to: to,
      rows: rows,
      total: total,
      generated_at: DateTime.utc_now()
    }
  end

  @doc """
  Renders a revenue report as a CSV binary.
  Always returns a binary.
  """
  @spec render_revenue_csv(RevenueReport.t()) :: binary()
  def render_revenue_csv(%RevenueReport{rows: rows}) do
    header = "date,amount\n"
    body = Enum.map_join(rows, "\n", &"#{&1.date},#{&1.amount}")
    header <> body
  end

  @doc """
  Renders a revenue report as a JSON-encodable map.
  Always returns a map.
  """
  @spec render_revenue_json(RevenueReport.t()) :: map()
  def render_revenue_json(%RevenueReport{} = report) do
    %{
      from: Date.to_iso8601(report.from),
      to: Date.to_iso8601(report.to),
      total: report.total,
      rows: Enum.map(report.rows, &%{date: Date.to_iso8601(&1.date), amount: &1.amount})
    }
  end

  @doc """
  Builds a summary report for a single month.
  Always returns a `SummaryReport` struct.
  """
  @spec build_summary(integer(), integer()) :: SummaryReport.t()
  def build_summary(year, month) do
    data = Analytics.monthly_summary(year, month)

    %SummaryReport{
      year: year,
      month: month,
      total_orders: data.order_count,
      total_revenue: data.revenue,
      avg_order_value: data.revenue / max(data.order_count, 1)
    }
  end
end

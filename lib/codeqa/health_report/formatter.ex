defmodule CodeQA.HealthReport.Formatter do
  @moduledoc "Renders health report as markdown in plain or github format."

  alias CodeQA.HealthReport.Formatter.AgentActions
  alias CodeQA.HealthReport.Formatter.Github
  alias CodeQA.HealthReport.Formatter.Plain

  @spec format_markdown(map(), atom(), atom(), atom()) :: String.t()
  def format_markdown(report, detail, format \\ :plain, view \\ :both)

  def format_markdown(report, _detail, _format, :actions), do: AgentActions.render(report)
  def format_markdown(report, detail, :plain, view), do: Plain.render(report, detail, view)
  def format_markdown(report, detail, :github, view), do: Github.render(report, detail, [], view)

  @doc """
  Renders the report as multiple parts for GitHub PR comments, scoped to `view`.

  - `:metrics` — Part 1 (header/summary/delta/chart) + Part 2 (top issues/categories)
  - `:actions` — a single agent-actions part
  - `:both` — metric parts followed by the agent-actions part

  Each metric part ends with a sentinel comment for sticky comment identification.
  """
  @spec render_parts(map(), keyword()) :: [String.t()]
  def render_parts(report, opts \\ []) do
    view = Keyword.get(opts, :view, :both)
    render_parts_for(view, report, opts)
  end

  defp render_parts_for(:metrics, report, opts),
    do: [Github.render_part_1(report, opts), Github.render_part_2(report, opts)]

  defp render_parts_for(:actions, report, _opts), do: [AgentActions.render(report)]

  defp render_parts_for(:both, report, opts),
    do: render_parts_for(:metrics, report, opts) ++ render_parts_for(:actions, report, opts)
end

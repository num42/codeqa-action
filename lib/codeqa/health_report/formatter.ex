defmodule CodeQA.HealthReport.Formatter do
  @moduledoc "Renders health report as markdown in plain or github format."

  alias CodeQA.HealthReport.Formatter.{Github, Plain}

  @spec format_markdown(map(), atom(), atom(), keyword()) :: String.t()
  def format_markdown(report, detail, format \\ :plain, opts \\ [])

  def format_markdown(report, detail, :plain, _opts), do: Plain.render(report, detail)
  def format_markdown(report, detail, :github, opts), do: Github.render(report, detail, opts)

  @doc """
  Renders the report as multiple parts for GitHub PR comments.
  Returns a flat list of strings: [part_1, part_2, part_3, ...].

  Part 1: Header, summary, PR summary, delta, chart, progress bars
  Part 2: Top issues, category detail sections
  Part 3+: Blocks section, sliced at 60,000 chars per part

  Each part ends with a sentinel comment for sticky comment identification.
  """
  @spec render_parts(map(), keyword()) :: [String.t()]
  def render_parts(report, opts \\ []) do
    part_1 = Github.render_part_1(report, opts)
    part_2 = Github.render_part_2(report, opts)
    parts_3 = Github.render_parts_3(report, opts)

    [part_1, part_2 | parts_3]
  end
end

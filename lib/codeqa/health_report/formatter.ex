defmodule CodeQA.HealthReport.Formatter do
  @moduledoc "Renders health report as markdown in plain or github format."

  alias CodeQA.HealthReport.Formatter.{Github, Plain}

  @spec format_markdown(map(), atom(), atom(), keyword()) :: String.t()
  def format_markdown(report, detail, format \\ :plain, opts \\ [])

  def format_markdown(report, detail, :plain, opts), do: Plain.render(report, detail, opts)
  def format_markdown(report, detail, :github, opts), do: Github.render(report, detail, opts)
end

defmodule CodeQA.Metrics.Inflector do
  @moduledoc "Utility for detecting identifier casing styles."

  def detect_casing(identifier) do
    cond do
      identifier =~ ~r/^[A-Z][a-zA-Z0-9]*$/ -> :pascal_case
      identifier =~ ~r/^[a-z][a-zA-Z0-9]*$/ -> :camel_case
      identifier =~ ~r/^[a-z]+(_[a-z0-9]+)*$/ -> :snake_case
      identifier =~ ~r/^[A-Z]+(_[A-Z0-9]+)*$/ -> :macro_case
      identifier =~ ~r/^[a-z]+(-[a-z0-9]+)*$/ -> :kebab_case
      true -> :other
    end
  end
end

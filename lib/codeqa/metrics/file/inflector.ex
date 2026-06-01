defmodule CodeQA.Metrics.File.Inflector do
  @moduledoc """
  Utility for detecting identifier casing styles.

  See [naming conventions](https://en.wikipedia.org/wiki/Naming_convention_(programming)).
  """

  @doc """
  Detects the casing style of an identifier string.

  Classification priority (first match wins):
  - `:pascal_case` — starts uppercase, no underscores (e.g. `FooBar`)
  - `:camel_case` — starts lowercase, contains at least one uppercase (e.g. `fooBar`)
  - `:snake_case` — all lowercase, words separated by underscores (e.g. `foo_bar`, `foo`)
  - `:macro_case` — all uppercase, words separated by underscores (e.g. `FOO_BAR`)
  - `:kebab_case` — all lowercase, words separated by hyphens (e.g. `foo-bar`)
  - `:other` — anything else

  ## Examples

      iex> CodeQA.Metrics.Inflector.detect_casing("foo")
      :snake_case

      iex> CodeQA.Metrics.Inflector.detect_casing("fooBar")
      :camel_case

      iex> CodeQA.Metrics.Inflector.detect_casing("FooBar")
      :pascal_case

      iex> CodeQA.Metrics.Inflector.detect_casing("FOO_BAR")
      :macro_case
  """
  @spec detect_casing(String.t()) ::
          :pascal_case | :camel_case | :snake_case | :macro_case | :kebab_case | :other
  def detect_casing(identifier) do
    cond do
      identifier =~ ~r/^[A-Z][a-zA-Z0-9]*$/ -> :pascal_case
      identifier =~ ~r/^[a-z][a-z0-9]*(?:[A-Z][a-zA-Z0-9]*)+$/ -> :camel_case
      identifier =~ ~r/^[a-z]+(_[a-z0-9]+)*$/ -> :snake_case
      identifier =~ ~r/^[A-Z]+(_[A-Z0-9]+)*$/ -> :macro_case
      identifier =~ ~r/^[a-z]+(-[a-z0-9]+)*$/ -> :kebab_case
      true -> :other
    end
  end
end

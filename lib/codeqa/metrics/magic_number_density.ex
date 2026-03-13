defmodule CodeQA.Metrics.MagicNumberDensity do
  @moduledoc """
  Measures the density of magic numbers in source code.

  Counts numeric literals (excluding common constants 0, 1, 0.0, 1.0) as a
  proportion of total tokens. A high density suggests unexplained constants
  that should be extracted into named values.

  See [magic number](<https://en.wikipedia.org/wiki/Magic_number_(programming)>).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "magic_number_density"

  @number_re ~r/\b\d+\.?\d*(?:[eE][+-]?\d+)?\b/

  @impl true
  def analyze(%{content: content, tokens: tokens}) do
    token_list = Tuple.to_list(tokens)
    total_tokens = length(token_list)

    if total_tokens == 0 do
      %{"density" => 0.0, "magic_number_count" => 0}
    else
      numbers =
        @number_re
        |> Regex.scan(content)
        |> List.flatten()
        |> Enum.reject(&(&1 in ["0", "1", "0.0", "1.0"]))

      magic_count = length(numbers)

      %{
        "density" => Float.round(magic_count / total_tokens, 4),
        "magic_number_count" => magic_count
      }
    end
  end
end

defmodule CodeQA.Metrics.File.Zipf do
  @moduledoc """
  Fits Zipf's law to the token frequency distribution.

  Ranks tokens by frequency and fits a power-law curve via log-linear
  regression. The exponent and R-squared indicate how closely the code's
  token usage follows natural-language-like frequency patterns.

  See [Zipf's law](https://en.wikipedia.org/wiki/Zipf%27s_law).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "zipf"

  @impl true
  def keys, do: ["exponent", "r_squared", "vocab_size", "total_tokens"]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{tokens: [], token_counts: _token_counts}) do
    %{"exponent" => 0.0, "r_squared" => 0.0, "vocab_size" => 0, "total_tokens" => 0}
  end

  def analyze(%{tokens: tokens, token_counts: token_counts}) do
    frequencies = token_counts |> Map.values() |> Enum.sort(:desc)
    vocab_size = length(frequencies)
    total_tokens = length(tokens)

    if vocab_size < 3 do
      %{
        "exponent" => 0.0,
        "r_squared" => 0.0,
        "vocab_size" => vocab_size,
        "total_tokens" => total_tokens
      }
    else
      {exponent, r_squared} = fit_zipf(frequencies, vocab_size)

      %{
        "exponent" => exponent,
        "r_squared" => r_squared,
        "vocab_size" => vocab_size,
        "total_tokens" => total_tokens
      }
    end
  end

  defp fit_zipf(frequencies, vocab_size) do
    ranks = 1..vocab_size |> Enum.to_list() |> Nx.tensor(type: :f64)
    freqs = Nx.tensor(frequencies, type: :f64)

    log_ranks = Nx.log(ranks)
    log_freqs = Nx.log(freqs)

    {slope, _intercept, r_squared} = CodeQA.Math.linear_regression(log_ranks, log_freqs)

    # Zipf: freq ∝ rank^(-s), so slope is negative; negate to return the positive exponent s
    {Float.round(-Nx.to_number(slope), 4), Float.round(Nx.to_number(r_squared), 4)}
  end
end

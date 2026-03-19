defmodule CodeQA.Metrics.File.RFC do
  @moduledoc """
  Response For a Class (RFC) — a coupling metric from the Chidamber & Kemerer suite.

  RFC ≈ number of distinct methods/functions reachable from this file, counting
  both locally-defined functions and distinct external call targets.

  Formula: `RFC = function_def_count + |distinct_call_targets|`

  Computed from the token stream without requiring a real AST:
  - Function definitions are detected by function-keyword tokens (`def`, `fn`, etc.)
    followed by an `<ID>` token.
  - Call targets are detected by `<ID>` tokens immediately followed by `(`.
    Duplicates are collapsed to a set.

  Higher RFC values indicate a module with more responsibility and more external
  coupling, correlating empirically with higher fault density.

  See [CK metrics suite](https://en.wikipedia.org/wiki/Programming_complexity#Chidamber_and_Kemerer_metrics).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @func_keywords MapSet.new(~w[
    def defp defmacro defmacrop defguard defdelegate
    function func fun fn
    sub proc method
  ])

  @impl true
  def name, do: "rfc"

  @impl true
  def keys, do: ["rfc_count", "rfc_density", "function_def_count", "distinct_call_count"]

  @impl true
  def description,
    do: "Response For a Class: function definitions + distinct call targets (CK suite)"

  @spec analyze(CodeQA.Engine.FileContext.t()) :: map()
  @impl true
  def analyze(%{tokens: tokens, line_count: line_count}) do
    {func_def_count, call_targets} = scan_tokens(tokens)

    distinct_call_count = MapSet.size(call_targets)
    rfc_count = func_def_count + distinct_call_count

    density =
      if line_count > 0,
        do: Float.round(rfc_count / line_count, 4),
        else: 0.0

    %{
      "rfc_count" => rfc_count,
      "rfc_density" => density,
      "function_def_count" => func_def_count,
      "distinct_call_count" => distinct_call_count
    }
  end

  # Single pass: detect function definitions and call sites simultaneously.
  # Uses a sliding window of two adjacent tokens.
  defp scan_tokens(tokens) do
    tokens
    |> Enum.zip(Enum.drop(tokens, 1))
    |> Enum.reduce({0, MapSet.new()}, fn {tok, next}, {defs, calls} ->
      cond do
        # Function definition: keyword followed by an identifier
        MapSet.member?(@func_keywords, tok.content) and next.kind == "<ID>" ->
          {defs + 1, calls}

        # Call site: identifier followed by open paren
        tok.kind == "<ID>" and next.content == "(" ->
          {defs, MapSet.put(calls, tok.content)}

        true ->
          {defs, calls}
      end
    end)
  end
end

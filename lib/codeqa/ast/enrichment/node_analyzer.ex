defmodule CodeQA.AST.Enrichment.NodeAnalyzer do
  @moduledoc """
  Extracts locally bound variable names from a token list.

  Used by the domain tagger to subtract local bindings from the domain signal —
  a variable bound within a node (e.g. `user = Repo.get!(id)`) is not a domain
  reference and should not appear in the node's domain fingerprint.
  """

  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Lexing.NewlineToken

  @doc """
  Returns a MapSet of lowercase identifier names that are locally bound
  within the given token list.

  Detected patterns:
  - `<ID> "="` — simple assignment (guards against `==`, `=>`, `=~`, `!=`, `<=`, `>=`)
  - `<ID> "<-"` — with/for binding (all `<ID>` tokens on the LHS of `<-`)

  Function parameters are NOT extracted here (see `param_variables/1`).
  """
  @spec bound_variables([Token.t()]) :: MapSet.t(String.t())
  def bound_variables(tokens) do
    MapSet.union(
      assignment_bindings(tokens),
      arrow_bindings(tokens)
    )
  end

  # Collect `<ID>` immediately before `=`
  defp assignment_bindings(tokens) do
    tokens
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [%Token{kind: "<ID>", content: name}, %Token{kind: "="}] ->
        [String.downcase(name)]

      _ ->
        []
    end)
    |> MapSet.new()
  end

  # Collect all `<ID>` tokens on the LHS of `<-` (within the same line).
  # Resets the accumulator on `<NL>` so RHS tokens from prior lines don't leak.
  defp arrow_bindings(tokens) do
    tokens
    |> Enum.reduce({[], MapSet.new()}, fn
      %Token{kind: "<-"}, {lhs_ids, acc} ->
        new_bindings = lhs_ids |> Enum.map(&String.downcase/1) |> MapSet.new()
        {[], MapSet.union(acc, new_bindings)}

      %NewlineToken{}, {_, acc} ->
        {[], acc}

      %Token{kind: "<ID>", content: name}, {lhs_ids, acc} ->
        {[name | lhs_ids], acc}

      _, {lhs_ids, acc} ->
        {lhs_ids, acc}
    end)
    |> elem(1)
  end
end

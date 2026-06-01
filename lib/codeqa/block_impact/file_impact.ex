defmodule CodeQA.BlockImpact.FileImpact do
  @moduledoc """
  Leave-one-out file metrics: reconstruct file content without a target node's tokens
  and return the re-run file metrics map.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Engine.Analyzer

  @min_tokens 10

  @doc """
  Computes file metrics for the content with the target node's tokens removed.

  Returns `nil` if the node has fewer than `#{@min_tokens}` tokens.
  Returns a raw `%{"group" => %{"key" => value}}` metrics map otherwise.
  """
  @spec compute(String.t(), Node.t()) :: map() | nil
  def compute(_content, %Node{tokens: tokens}) when length(tokens) < @min_tokens, do: nil

  def compute(content, node) do
    root_tokens = TokenNormalizer.normalize_structural(content)
    reconstructed = reconstruct_without(root_tokens, node)
    Analyzer.analyze_file("", reconstructed)
  end

  @spec reconstruct_without([CodeQA.AST.Lexing.Token.t()], Node.t()) :: String.t()
  def reconstruct_without(root_tokens, %Node{tokens: []}) do
    Enum.map_join(root_tokens, "", & &1.content)
  end

  def reconstruct_without(root_tokens, node) do
    first = List.first(node.tokens)

    case Enum.find_index(root_tokens, fn t -> t.line == first.line and t.col == first.col end) do
      nil ->
        Enum.map_join(root_tokens, "", & &1.content)

      start_idx ->
        end_idx = start_idx + length(node.tokens)
        remaining = Enum.take(root_tokens, start_idx) ++ Enum.drop(root_tokens, end_idx)
        Enum.map_join(remaining, "", & &1.content)
    end
  end
end

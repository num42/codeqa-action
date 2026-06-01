defmodule CodeQA.BlockImpact.CodebaseImpact do
  @moduledoc """
  Leave-one-out codebase aggregate: reconstruct file content without a target node,
  replace the file in the files map, and re-run the codebase aggregate.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.BlockImpact.FileImpact
  alias CodeQA.Engine.Analyzer

  @doc """
  Returns the codebase aggregate after removing the target node from the given file.
  """
  @spec compute(String.t(), String.t(), Node.t(), map()) :: map()
  def compute(path, content, node, files_map) do
    root_tokens = TokenNormalizer.normalize_structural(content)
    reconstructed = FileImpact.reconstruct_without(root_tokens, node)
    updated_files = Map.put(files_map, path, reconstructed)
    Analyzer.analyze_codebase_aggregate(updated_files)
  end
end

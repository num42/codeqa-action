defmodule CodeQA.AST.Classification.NodeTypeDetector do
  @moduledoc """
  Classifies a list of raw `Node` structs (from `Parser`) into typed structs.

  Each node is classified by `NodeClassifier`, which runs classification signals
  over the node's tokens and picks the highest-voted type. See `NodeClassifier`
  for the full list of signals and their weights.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Classification.NodeClassifier

  @doc """
  Classify each node in the list into the most specific typed struct.
  """
  @spec detect_types([Node.t()], module()) :: [term()]
  def detect_types(blocks, lang_mod) do
    Enum.map(blocks, &NodeClassifier.classify(&1, lang_mod))
  end
end

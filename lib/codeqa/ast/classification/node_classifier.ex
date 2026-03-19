defmodule CodeQA.AST.Classification.NodeClassifier do
  @moduledoc """
  Classifies a Node into a typed struct by running classification signals
  over its tokens and weighing their votes.

  ## How it works

  Six classification signals scan the node's token stream in parallel via
  `SignalStream`. Each signal emits weighted votes (e.g. `{:function_vote, 3}`)
  when it detects a pattern indicating a node type. The classifier sums weights
  per type and picks the winner. Ties and no-votes fall back to `:code`.

  ## Signals and votes

  | Signal | Vote key | Patterns detected |
  |---|---|---|
  | `DocSignal` | `:doc_vote` | `<DOC>` token anywhere |
  | `AttributeSignal` | `:attribute_vote` | `@name` at indent 0 |
  | `FunctionSignal` | `:function_vote` | `def`, `func`, `fn`, etc. at indent 0 |
  | `ModuleSignal` | `:module_vote` | `defmodule`, `class`, `module`, etc. at indent 0 |
  | `ImportSignal` | `:import_vote` | `import`, `use`, `alias`, etc. at indent 0 |
  | `TestSignal` | `:test_vote` | `test`, `describe`, `it`, etc. at indent 0 |

  ## Weights

  Weight 3 = first keyword seen (strong match); weight 1 = keyword later in
  block (weak match, e.g. after a leading comment). `DocSignal` always emits
  weight 3 and wins when a `<DOC>` token is present, since triple-quoted strings
  are unambiguous.

  ## Type-specific fields

  `FunctionNode.name/arity/visibility`, `ModuleNode.name/kind`, etc. all default
  to `nil`. Population of those fields is left to a future enrichment pass.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Parsing.SignalStream

  alias CodeQA.AST.Signals.Classification.{
    DocSignal,
    AttributeSignal,
    FunctionSignal,
    ModuleSignal,
    ImportSignal,
    TestSignal
  }

  alias CodeQA.AST.Nodes.{
    CodeNode,
    DocNode,
    FunctionNode,
    ModuleNode,
    ImportNode,
    AttributeNode,
    TestNode
  }

  @classification_signals [
    %DocSignal{},
    %AttributeSignal{},
    %FunctionSignal{},
    %ModuleSignal{},
    %ImportSignal{},
    %TestSignal{}
  ]

  @type_modules %{
    doc: DocNode,
    attribute: AttributeNode,
    function: FunctionNode,
    module: ModuleNode,
    import: ImportNode,
    test: TestNode,
    code: CodeNode
  }

  @doc """
  Classify a Node into the most specific typed struct.

  Runs classification signals, weighs votes, and delegates to the winning
  struct's `cast/1` to build the result. Type-specific fields default to nil.
  """
  @spec classify(Node.t(), module()) :: term()
  def classify(%Node{} = node, lang_mod) do
    type = vote(node.tokens, lang_mod)
    @type_modules[type].cast(node)
  end

  defp vote(tokens, lang_mod) do
    tokens
    |> run_signals(lang_mod)
    |> tally()
    |> winner()
  end

  defp run_signals(tokens, lang_mod) do
    SignalStream.run(tokens, @classification_signals, lang_mod)
    |> List.flatten()
    |> Enum.filter(fn {_src, group, _name, _val} -> group == :classification end)
  end

  defp tally(emissions) do
    Enum.reduce(emissions, %{}, fn {_src, _grp, name, weight}, acc ->
      Map.update(acc, name, weight, &(&1 + weight))
    end)
  end

  defp winner(votes) when map_size(votes) == 0, do: :code

  defp winner(votes) do
    {vote_name, _weight} = Enum.max_by(votes, fn {_, w} -> w end)
    vote_to_type(vote_name)
  end

  defp vote_to_type(:doc_vote), do: :doc
  defp vote_to_type(:attribute_vote), do: :attribute
  defp vote_to_type(:function_vote), do: :function
  defp vote_to_type(:module_vote), do: :module
  defp vote_to_type(:import_vote), do: :import
  defp vote_to_type(:test_vote), do: :test
  defp vote_to_type(_), do: :code
end

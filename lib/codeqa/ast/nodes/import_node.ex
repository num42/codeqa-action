defmodule CodeQA.AST.Nodes.ImportNode do
  @moduledoc "AST node for import, require, use, alias, or include statements."

  alias CodeQA.AST.Enrichment.Node
  import CodeQA.AST.Nodes.Shared, only: [cast_shared: 2]

  defstruct [:children, :end_line, :label, :line_count, :start_line, :target, :tokens]

  @type t :: %__MODULE__{
          children: [term()],
          end_line: non_neg_integer() | nil,
          label: term() | nil,
          line_count: non_neg_integer(),
          start_line: non_neg_integer() | nil,
          target: String.t() | nil,
          tokens: [term()]
        }

  @doc "Build an ImportNode from a raw %Node{}, copying all base fields. Type-specific fields default to nil."
  @spec cast(Node.t()) :: t()
  def cast(%Node{} = node), do: cast_shared(__MODULE__, node)

  defimpl CodeQA.AST.Classification.NodeProtocol do
    alias CodeQA.AST.Classification.NodeProtocol

    def tokens(n), do: n.tokens
    def line_count(n), do: n.line_count
    def children(n), do: n.children
    def start_line(n), do: n.start_line
    def end_line(n), do: n.end_line
    def label(n), do: n.label

    def flat_tokens(n) do
      if n.children |> Enum.empty?(),
        do: n.tokens,
        else: n.children |> Enum.flat_map(&NodeProtocol.flat_tokens/1)
    end
  end
end

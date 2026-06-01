defmodule CodeQA.AST.Nodes.TestNode do
  @moduledoc "AST node for test cases, describe blocks, and it blocks."

  alias CodeQA.AST.Enrichment.Node
  import CodeQA.AST.Nodes.Shared, only: [cast_shared: 2]

  defstruct [:tokens, :line_count, :children, :start_line, :end_line, :label, :description]

  @type t :: %__MODULE__{
          tokens: [term()],
          line_count: non_neg_integer(),
          children: [term()],
          start_line: non_neg_integer() | nil,
          end_line: non_neg_integer() | nil,
          label: term() | nil,
          description: String.t() | nil
        }

  @doc "Build a TestNode from a raw %Node{}, copying all base fields. Type-specific fields default to nil."
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

defmodule CodeQA.AST.Nodes.FunctionNode do
  @moduledoc "AST node for function, method, or callable definitions."

  alias CodeQA.AST.Enrichment.Node
  import CodeQA.AST.Nodes.Shared, only: [cast_shared: 2]

  defstruct [
    :arity,
    :children,
    :end_line,
    :label,
    :line_count,
    :name,
    :start_line,
    :tokens,
    :visibility
  ]

  @type t :: %__MODULE__{
          arity: non_neg_integer() | nil,
          children: [term()],
          end_line: non_neg_integer() | nil,
          label: term() | nil,
          line_count: non_neg_integer(),
          name: String.t() | nil,
          start_line: non_neg_integer() | nil,
          tokens: [term()],
          visibility: :public | :private | nil
        }

  @doc "Build a FunctionNode from a raw %Node{}, copying all base fields. Type-specific fields default to nil."
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

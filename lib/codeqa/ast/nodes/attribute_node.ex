defmodule CodeQA.AST.Nodes.AttributeNode do
  @moduledoc """
  AST node for fields, constants, decorators, annotations, and typespecs.
  Subsumes the previous :typespec node type (kind: :typespec).
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.{NewlineToken, WhitespaceToken}

  defstruct [:tokens, :line_count, :children, :start_line, :end_line, :label, :name, :kind]

  @type t :: %__MODULE__{
          tokens: [term()],
          line_count: non_neg_integer(),
          children: [term()],
          start_line: non_neg_integer() | nil,
          end_line: non_neg_integer() | nil,
          label: term() | nil,
          name: String.t() | nil,
          kind: :field | :constant | :decorator | :annotation | :typespec | nil
        }

  @typespec_attrs MapSet.new(~w[spec type typep opaque callback macrocallback])

  @doc "Build an AttributeNode from a raw %Node{}, detecting :typespec kind from tokens."
  @spec cast(Node.t()) :: t()
  def cast(%Node{} = node) do
    %__MODULE__{
      tokens: node.tokens,
      line_count: node.line_count,
      children: node.children,
      start_line: node.start_line,
      end_line: node.end_line,
      label: node.label,
      kind: detect_kind(node.tokens)
    }
  end

  defp detect_kind(tokens) do
    tokens
    |> Enum.drop_while(&(&1.kind in [WhitespaceToken.kind(), NewlineToken.kind()]))
    |> case do
      [%{kind: "@"}, %{kind: "<ID>", content: name} | _] ->
        if MapSet.member?(@typespec_attrs, name), do: :typespec, else: nil

      _ ->
        nil
    end
  end

  defimpl CodeQA.AST.Classification.NodeProtocol do
    def tokens(n), do: n.tokens
    def line_count(n), do: n.line_count
    def children(n), do: n.children
    def start_line(n), do: n.start_line
    def end_line(n), do: n.end_line
    def label(n), do: n.label

    def flat_tokens(n) do
      if Enum.empty?(n.children),
        do: n.tokens,
        else: Enum.flat_map(n.children, &CodeQA.AST.Classification.NodeProtocol.flat_tokens/1)
    end
  end
end

defmodule CodeQA.AST.Enrichment.CompoundNodeBuilder do
  @moduledoc """
  Groups typed nodes into CompoundNode structs.

  A new compound starts when:
  1. A :doc or :typespec node appears after at least one :code node
  2. The trailing whitespace of the previous node contains 2+ <NL> tokens

  All consecutive :code nodes with no boundary between them accumulate
  into the same compound's `code` list.

  Sub-blocks of :code nodes that have type :doc or :typespec are
  promoted to the compound's `docs`/`typespecs` lists.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Enrichment.CompoundNode
  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Nodes.{DocNode, AttributeNode}
  alias CodeQA.AST.Lexing.{NewlineToken, WhitespaceToken}

  @doc """
  Groups a list of typed nodes into CompoundNode structs.
  """
  @spec build([Node.t()]) :: [CompoundNode.t()]
  def build([]), do: []

  def build(blocks) do
    # Accumulator: {current_compound, prev_trailing_ws, finalized_compounds}
    # prev_trailing_ws carries the trailing <NL>/<WS> tokens stripped from the
    # PREVIOUS node. Blank-line boundaries are detected on the previous node's
    # trailing whitespace — BlankLineRule places blank-line <NL> tokens at the
    # END of the node that precedes the split, not at the start of the new one.
    {current, _, compounds} =
      Enum.reduce(blocks, {empty_compound(), [], []}, fn block,
                                                         {current, prev_trailing_ws, acc} ->
        {content_tokens, trailing_ws} = split_trailing_whitespace(block.tokens)
        clean_block = %{block | tokens: content_tokens}
        # Check the PREVIOUS node's trailing whitespace for blank-line boundary
        blank_boundary = blank_line_boundary?(prev_trailing_ws)

        cond do
          # Rule 1: doc/typespec after code → flush and start new compound
          (is_struct(block, DocNode) or is_struct(block, AttributeNode)) and current.code != [] ->
            {start_compound(clean_block), trailing_ws, [finalize(current) | acc]}

          # Rule 2: blank-line boundary on previous node → flush and start fresh
          blank_boundary and not empty_compound?(current) ->
            {start_compound(clean_block), trailing_ws, [finalize(current) | acc]}

          # No boundary — accumulate into current
          true ->
            {add_block(current, clean_block), trailing_ws, acc}
        end
      end)

    compounds
    |> then(fn acc ->
      if empty_compound?(current), do: acc, else: [finalize(current) | acc]
    end)
    |> Enum.reverse()
  end

  defp empty_compound, do: %CompoundNode{}

  defp empty_compound?(%CompoundNode{docs: [], typespecs: [], code: []}), do: true
  defp empty_compound?(_), do: false

  defp add_block(%CompoundNode{} = compound, block) when is_struct(block, DocNode) do
    %CompoundNode{compound | docs: compound.docs ++ [block]}
  end

  defp add_block(%CompoundNode{} = compound, block) when is_struct(block, AttributeNode) do
    %CompoundNode{compound | typespecs: compound.typespecs ++ [block]}
  end

  defp add_block(%CompoundNode{} = compound, block) do
    {promoted_docs, promoted_specs, clean_children} = promote_sub_blocks(block.children)
    clean_block = %{block | children: clean_children}

    %CompoundNode{
      compound
      | code: compound.code ++ [clean_block],
        docs: compound.docs ++ promoted_docs,
        typespecs: compound.typespecs ++ promoted_specs
    }
  end

  defp start_compound(new_block) do
    add_block(empty_compound(), new_block)
  end

  # Separates children by type — :doc/:typespec go up to the compound level.
  defp promote_sub_blocks(children) do
    Enum.reduce(children, {[], [], []}, fn sub, {docs, specs, code} ->
      case sub.type do
        :doc -> {docs ++ [sub], specs, code}
        :typespec -> {docs, specs ++ [sub], code}
        _ -> {docs, specs, code ++ [sub]}
      end
    end)
  end

  # Strips trailing <WS>/<NL> tokens from a node's token list.
  # Returns {content_tokens, trailing_ws_tokens}.
  defp split_trailing_whitespace(tokens) do
    last_content_idx =
      tokens
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.find_index(fn {t, _} ->
        not is_map(t) or t.kind not in [WhitespaceToken.kind(), NewlineToken.kind()]
      end)

    case last_content_idx do
      nil ->
        {[], tokens}

      rev_idx ->
        content_len = length(tokens) - rev_idx
        {Enum.slice(tokens, 0, content_len), Enum.slice(tokens, content_len..-1//1)}
    end
  end

  # A blank-line boundary exists when the trailing whitespace contains 3+ <NL> tokens
  # (i.e. 2+ blank lines). A single blank line (2 NLs: end-of-line + blank line) is
  # common within a compound (e.g. between function clauses) and does not split.
  defp blank_line_boundary?(trailing_ws) do
    Enum.count(trailing_ws, &(&1.kind == NewlineToken.kind())) >= 3
  end

  # Computes boundaries from all constituent nodes in source order:
  # docs → typespecs → code. Reads col directly from Token structs.
  defp finalize(%CompoundNode{} = compound) do
    all_blocks = compound.docs ++ compound.typespecs ++ compound.code
    all_tokens = Enum.flat_map(all_blocks, &NodeProtocol.flat_tokens/1)

    first_token =
      Enum.find(
        all_tokens,
        &(is_map(&1) and &1.kind not in [WhitespaceToken.kind(), NewlineToken.kind()])
      )

    last_token =
      all_tokens
      |> Enum.reverse()
      |> Enum.find(&(is_map(&1) and &1.kind not in [WhitespaceToken.kind(), NewlineToken.kind()]))

    %CompoundNode{
      compound
      | start_line: first_token && first_token.line,
        start_col: first_token && first_token.col,
        end_line: last_token && last_token.line,
        end_col: last_token && last_token.col
    }
  end
end

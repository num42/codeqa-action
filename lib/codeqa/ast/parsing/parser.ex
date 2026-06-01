defmodule CodeQA.AST.Parsing.Parser do
  @moduledoc """
  Recursively parses a token stream into a nested node tree.

  Top-level nodes are found by splitting on blank lines and declaration keywords.
  Each node is then recursively subdivided using enclosure rules (brackets,
  colon-indentation) until no further subdivision is possible — forming an
  arbitrarily-deep tree rather than a fixed two-level hierarchy.

  ## Recursive parsing algorithm

  `parse_block/3` is the recursive core:

  1. Immediately create a `Node` spanning the whole token stream.
  2. Apply enclosure rules to find sub-candidate streams.
  3. **Idempotency check** — reject any enclosure that spans the entire stream
     (e.g. `BracketRule` re-emitting its own input). This is the termination
     condition: the node is a leaf when no strictly-smaller sub-candidates exist.
  4. Recursively call `parse_block/3` on each sub-candidate to produce children.
  5. Return the node with its children attached as `children`.

  ## Design notes (from tree-sitter, ctags, lizard)

  - **Recursive hierarchy** — replaces the old two-level (top + one level of sub-blocks)
    model with an N-level tree. Each call to `parse_block/3` mirrors tree-sitter's
    recursive descent: emit the node, then recurse into its contents.
  - **Language detection by extension** — `language_from_path/1` follows ctags'
    convention of inferring language from file extension.
  - **Rule extensibility** — enclosure rules are selected per language via
    `sub_block_rules/1`. Rules are composable and order-independent.
  - **Error recovery** — mismatched brackets and malformed indentation are silently
    skipped by individual rules. The parser emits partial nodes rather than failing,
    consistent with tree-sitter's error-recovery philosophy.
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.{NewlineToken, WhitespaceToken}
  alias CodeQA.AST.Parsing.SignalStream

  alias CodeQA.AST.Signals.Structural.{
    BlankLineSignal,
    BracketSignal,
    ColonIndentSignal,
    KeywordSignal,
    TripleQuoteSignal
  }

  alias CodeQA.Language

  @spec detect_blocks([CodeQA.AST.Lexing.Token.t()], module()) :: [Node.t()]
  def detect_blocks([], _lang_mod), do: []

  def detect_blocks(tokens, lang_mod) do
    all_emissions =
      SignalStream.run(
        tokens,
        [%TripleQuoteSignal{}, %BlankLineSignal{}, %KeywordSignal{}],
        lang_mod
      )
      |> List.flatten()

    triple_splits =
      for {_, :split, :triple_split, v} <- all_emissions, do: v

    protected_ranges = compute_protected_ranges(triple_splits)

    split_points =
      for(
        {_, :split, name, v} <- all_emissions,
        name in [:blank_split, :keyword_split],
        not inside_protected?(v, protected_ranges),
        do: v
      )
      |> Enum.concat(triple_splits)
      |> Enum.uniq()
      |> Enum.sort()

    tokens
    |> split_at(split_points)
    |> Enum.reject(fn s -> Enum.empty?(s) or whitespace_only?(s) end)
    |> merge_same_line_slices()
    |> Enum.map(&parse_block(&1, lang_mod))
  end

  @spec language_module_for_path(String.t()) :: module()
  def language_module_for_path(path), do: Language.detect(path)

  @spec language_from_path(String.t()) :: atom()
  def language_from_path(path),
    do: path |> Language.detect() |> then(& &1.name()) |> String.to_atom()

  # Recursively parse a token stream into a Node with nested children.
  # Immediately creates a node spanning the whole stream, then attempts to
  # subdivide it. Terminates when no strictly-smaller sub-candidates are found.
  defp parse_block(tokens, lang_mod) do
    start_line = block_start_line(tokens)
    end_line = block_end_line(tokens)
    line_count = if start_line && end_line, do: end_line - start_line + 1, else: 1

    block = %Node{
      tokens: tokens,
      line_count: line_count,
      children: [],
      start_line: start_line,
      end_line: end_line
    }

    case find_sub_candidates(tokens, lang_mod) do
      [] ->
        block

      candidates ->
        children = Enum.map(candidates, &parse_block(&1, lang_mod))
        %{block | children: children}
    end
  end

  # Collect enclosure regions from rules.
  #
  # If the token stream is itself a bracket pair (e.g. the stream IS `(foo, bar)`),
  # we unwrap the outer brackets before running rules. Without this, BracketRule
  # would only find the whole stream as a single enclosure — filtered by the
  # idempotency check — and recursion would stop prematurely at every bracket level.
  # Unwrapping lets us see the *inner* structure and keeps the tree growing deeper.
  #
  # Idempotency check: after unwrapping, reject any enclosure that still spans the
  # entire search window (0..n-1), which would produce an infinite loop.
  defp find_sub_candidates(tokens, lang_mod) do
    {search_tokens, _} = maybe_unwrap_bracket(tokens)
    n = length(search_tokens)

    enclosure_signals =
      if lang_mod.uses_colon_indent?() do
        [%BracketSignal{}, %ColonIndentSignal{}]
      else
        [%BracketSignal{}]
      end

    SignalStream.run(search_tokens, enclosure_signals, lang_mod)
    |> List.flatten()
    |> Enum.filter(fn {_, group, _, _} -> group == :enclosure end)
    |> Enum.map(fn {_, _, _, {s, e}} -> {s, e} end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reject(fn {s, e} -> s == 0 and e == n - 1 end)
    |> Enum.map(fn {s, e} -> Enum.slice(search_tokens, s..e) end)
    |> Enum.reject(&whitespace_only?/1)
  end

  @open_brackets MapSet.new(["(", "[", "{"])
  @matching_close %{"(" => ")", "[" => "]", "{" => "}"}

  # If the stream is a balanced bracket pair, return the inner tokens.
  # Otherwise return the stream unchanged.
  defp maybe_unwrap_bracket([first | rest] = tokens) do
    last = List.last(tokens)

    if last && MapSet.member?(@open_brackets, first.kind) &&
         Map.get(@matching_close, first.kind) == last.kind do
      {Enum.drop(rest, -1), 1}
    else
      {tokens, 0}
    end
  end

  defp maybe_unwrap_bracket([]), do: {[], 0}

  # Pairs consecutive triple-quote split indices into protected interior ranges.
  # Uses chunk_every with :discard to safely handle odd counts (malformed input).
  defp compute_protected_ranges(split_indices) do
    split_indices
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(fn [a, b] -> {a + 1, b - 1} end)
  end

  defp inside_protected?(idx, ranges) do
    Enum.any?(ranges, fn {lo, hi} -> idx >= lo and idx <= hi end)
  end

  # When TripleQuoteSignal splits `@doc """` mid-line, the tokens before the
  # triple-quote land in one slice and the heredoc in the next — both on the same
  # starting line. Merge adjacent slices that share a line boundary so `@doc """..."""`
  # becomes a single token stream fed to parse_block rather than two separate nodes.
  defp merge_same_line_slices([]), do: []
  defp merge_same_line_slices([single]), do: [single]

  defp merge_same_line_slices([slice_a, slice_b | rest]) do
    last_line_a =
      slice_a
      |> Enum.reverse()
      |> Enum.find(&(&1.kind not in [WhitespaceToken.kind(), NewlineToken.kind()]))
      |> then(&(&1 && &1.line))

    first_line_b =
      slice_b
      |> Enum.find(&(&1.kind not in [WhitespaceToken.kind(), NewlineToken.kind()]))
      |> then(&(&1 && &1.line))

    if last_line_a && first_line_b && last_line_a == first_line_b do
      merge_same_line_slices([slice_a ++ slice_b | rest])
    else
      [slice_a | merge_same_line_slices([slice_b | rest])]
    end
  end

  defp split_at(tokens, []), do: [tokens]

  defp split_at(tokens, split_points) do
    boundaries = [0 | split_points] ++ [length(tokens)]

    boundaries
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [start, stop] -> Enum.slice(tokens, start..(stop - 1)//1) end)
  end

  defp whitespace_only?(tokens) do
    Enum.all?(tokens, &(&1.kind in [WhitespaceToken.kind(), NewlineToken.kind()]))
  end

  defp block_start_line([%{line: line} | _]), do: line
  defp block_start_line([]), do: nil

  defp block_end_line([]), do: nil

  defp block_end_line(tokens) do
    tokens
    |> Enum.reverse()
    |> Enum.find(&(&1.kind not in [WhitespaceToken.kind(), NewlineToken.kind()]))
    |> case do
      nil -> tokens |> List.last() |> Map.get(:line)
      token -> token.line
    end
  end
end

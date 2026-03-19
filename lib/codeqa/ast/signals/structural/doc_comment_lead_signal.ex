defmodule CodeQA.AST.Signals.Structural.DocCommentLeadSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:doc_comment_split` when a doc-comment opener appears at line start.

  Detects:
  - `///` — Rust/C# XML doc comments: `//` token immediately followed by `/`
  - `/**` — Java/JS JSDoc: `/` token at line start immediately followed by `*`

  No split is emitted for the first such line (seen_content must be true).
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.DocCommentLeadSignal
    def group(_), do: :split

    def init(_, _lang_mod), do: %{idx: 0, at_line_start: true, seen_content: false}

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx, at_line_start: true} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(
          _,
          {_, %{kind: "//"}, next},
          %{idx: idx, at_line_start: true, seen_content: true} = state
        ) do
      base = %{state | idx: idx + 1, at_line_start: false}

      emissions =
        if next != nil and next.kind == "/",
          do: MapSet.new([{:doc_comment_split, idx}]),
          else: MapSet.new()

      {emissions, base}
    end

    def emit(
          _,
          {_, %{kind: "/"}, next},
          %{idx: idx, at_line_start: true, seen_content: true} = state
        ) do
      base = %{state | idx: idx + 1, at_line_start: false}

      emissions =
        if next != nil and next.kind in ["*", "**"],
          do: MapSet.new([{:doc_comment_split, idx}]),
          else: MapSet.new()

      {emissions, base}
    end

    def emit(_, {_, _, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: false, seen_content: true}}
  end
end

defmodule CodeQA.AST.Signals.Structural.SQLBlockSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:sql_block_split` when a SQL DDL or DML statement keyword appears
  at line start after prior content has been seen.

  Recognises uppercase and lowercase SQL statement starters:
  DDL: CREATE, DROP, ALTER, TRUNCATE
  DML: INSERT, UPDATE, DELETE, SELECT
  Procedures/transactions: BEGIN, COMMIT, ROLLBACK, CALL, EXECUTE

  When `opts[:language_module]` is set, uses that language's
  `statement_keywords/0` callback.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.SQLBlockSignal
    def group(_), do: :split

    def init(_, lang_mod) do
      keywords = CodeQA.Language.statement_keywords(lang_mod)
      %{idx: 0, at_line_start: true, seen_content: false, keywords: keywords}
    end

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx, at_line_start: true} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, %{kind: "<ID>"} = token, _}, %{idx: idx} = state) do
      base = %{state | idx: idx + 1, at_line_start: false, seen_content: true}

      emissions =
        if sql_split?(state, token), do: MapSet.new([{:sql_block_split, idx}]), else: MapSet.new()

      {emissions, base}
    end

    def emit(_, {_, _, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: false, seen_content: true}}

    defp sql_split?(%{seen_content: true, at_line_start: true, keywords: kw}, %{content: c}),
      do: MapSet.member?(kw, String.downcase(c))

    defp sql_split?(_, _), do: false
  end
end

defmodule CodeQA.AST.Signals.Structural.BlankLineSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:blank_split` at the first substantive token after 2+ consecutive
  blank lines that follow a known block-end token.

  When `opts[:language_module]` is set, uses that language's
  `block_end_tokens/0` callback.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.BlankLineSignal
    def group(_), do: :split

    def init(_, lang_mod) do
      tokens = CodeQA.Language.block_end_tokens(lang_mod)
      %{idx: 0, nl_run: 0, seen_content: false, last_content: nil, block_end_tokens: tokens}
    end

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx, nl_run: nl} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, nl_run: nl + 1}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, token, _}, %{idx: idx} = state) do
      base = %{state | idx: idx + 1, nl_run: 0, seen_content: true, last_content: token.content}

      emissions =
        if blank_split?(state), do: MapSet.new([{:blank_split, idx}]), else: MapSet.new()

      {emissions, base}
    end

    defp blank_split?(%{seen_content: true, nl_run: nl, block_end_tokens: t, last_content: lc})
         when nl >= 2,
         do: MapSet.member?(t, lc)

    defp blank_split?(_), do: false
  end
end

defmodule CodeQA.AST.Signals.Structural.DedentToZeroSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:dedent_split` when code returns to indent level 0 after having been
  at indent > 0 on the previous line.

  This is the primary split mechanism for Python and other indentation-significant
  languages. The split fires at the first substantive token on a line that has no
  leading `<WS>`, when the previous line did have leading `<WS>`.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.DedentToZeroSignal
    def group(_), do: :split

    def init(_, _lang_mod),
      do: %{
        at_line_start: true,
        current_line_has_content: false,
        current_line_has_indent: false,
        idx: 0,
        prev_line_had_indent: false,
        seen_content: false
      }

    def emit(
          _,
          {_, %NewlineToken{}, _},
          %{
            current_line_has_content: clhc,
            current_line_has_indent: clhi,
            idx: idx,
            prev_line_had_indent: plhi
          } = state
        ) do
      new_plhi = if clhc, do: clhi, else: plhi

      {MapSet.new(),
       %{
         state
         | idx: idx + 1,
           at_line_start: true,
           prev_line_had_indent: new_plhi,
           current_line_has_indent: false,
           current_line_has_content: false
       }}
    end

    def emit(_, {_, %WhitespaceToken{}, _}, %{at_line_start: true, idx: idx} = state),
      do:
        {MapSet.new(),
         %{state | idx: idx + 1, current_line_has_indent: true, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, _, _}, %{idx: idx} = state) do
      base = %{
        state
        | idx: idx + 1,
          at_line_start: false,
          seen_content: true,
          current_line_has_content: true
      }

      emissions =
        if dedent_split?(state), do: MapSet.new([{:dedent_split, idx}]), else: MapSet.new()

      {emissions, base}
    end

    defp dedent_split?(%{
           at_line_start: true,
           current_line_has_indent: false,
           prev_line_had_indent: true,
           seen_content: true
         }),
         do: true

    defp dedent_split?(_), do: false
  end
end

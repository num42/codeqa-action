defmodule CodeQA.AST.Signals.Structural.DecoratorSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:decorator_split` when a decorator/annotation marker appears at line
  start with bracket_depth == 0.

  Detects two patterns:
  - `@` at line start (Python, TypeScript, Java, Elixir decorators/annotations)
  - `#[` at line start (Rust attribute syntax)
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.DecoratorSignal
    def group(_), do: :split

    def init(_, _lang_mod),
      do: %{at_line_start: true, bracket_depth: 0, idx: 0, seen_content: false}

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{at_line_start: true, idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, %{kind: k}, _}, %{bracket_depth: bd, idx: idx} = state)
        when k in ["(", "[", "{"],
        do:
          {MapSet.new(),
           %{
             state
             | idx: idx + 1,
               bracket_depth: bd + 1,
               seen_content: true,
               at_line_start: false
           }}

    def emit(_, {_, %{kind: k}, _}, %{bracket_depth: bd, idx: idx} = state)
        when k in [")", "]", "}"],
        do:
          {MapSet.new(),
           %{
             state
             | idx: idx + 1,
               bracket_depth: max(0, bd - 1),
               seen_content: true,
               at_line_start: false
           }}

    def emit(
          _,
          {_, %{kind: "@"}, _},
          %{at_line_start: true, bracket_depth: 0, idx: idx, seen_content: true} = state
        ),
        do:
          {MapSet.new([{:decorator_split, idx}]),
           %{state | idx: idx + 1, seen_content: true, at_line_start: false}}

    def emit(
          _,
          {_, %{kind: "#"}, next},
          %{at_line_start: true, bracket_depth: 0, idx: idx, seen_content: true} = state
        ) do
      emissions =
        if next != nil and next.kind == "[",
          do: MapSet.new([{:decorator_split, idx}]),
          else: MapSet.new()

      {emissions, %{state | idx: idx + 1, seen_content: true, at_line_start: false}}
    end

    def emit(_, {_, _, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, seen_content: true, at_line_start: false}}
  end
end

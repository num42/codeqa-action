defmodule CodeQA.AST.Lexing.StringToken do
  @moduledoc """
  A string token emitted by `TokenNormalizer` for all string literals,
  including triple-quoted heredocs.

  ## Fields

  - `kind`           — `"<STR>"` for single-line strings, `"<DOC>"` for
                       triple-quoted heredoc delimiters.
  - `content`        — original source text (the full quoted literal or delimiter).
  - `line`, `col`    — source location.
  - `interpolations` — list of interpolation expressions (`nil` for plain strings).
  - `multiline`      — `true` for triple-quoted (`\"\"\"` / `'''`) tokens.
  - `quotes`         — `:double`, `:single`, or `:backtick`.
  """

  @kind "<STR>"
  @doc_kind "<DOC>"

  defstruct [
    :content,
    :line,
    :col,
    kind: @kind,
    interpolations: nil,
    multiline: false,
    quotes: :double
  ]

  @doc "Returns the normalized kind string for single-line string tokens."
  @spec kind() :: String.t()
  def kind, do: @kind

  @doc "Returns the normalized kind string for triple-quoted doc string tokens."
  @spec doc_kind() :: String.t()
  def doc_kind, do: @doc_kind

  @type quotes :: :double | :single | :backtick

  @type t :: %__MODULE__{
          content: String.t(),
          line: non_neg_integer() | nil,
          col: non_neg_integer() | nil,
          kind: String.t(),
          interpolations: [String.t()] | nil,
          multiline: boolean(),
          quotes: quotes()
        }
end

defmodule CodeQA.AST.Lexing.WhitespaceToken do
  @moduledoc """
  A whitespace/indentation token emitted by `TokenNormalizer.normalize_structural/1`.

  Represents one indentation unit (2 spaces or 1 tab) at the start of a line.

  ## Fields

  - `kind`    — always `"<WS>"`.
  - `content` — the original source text for this indentation unit (`"  "`).
  - `line`    — 1-based line number in the source file.
  - `col`     — 0-based byte offset from the start of the line.
  """

  @kind "<WS>"

  defstruct [:content, :line, :col, kind: @kind]

  @doc "Returns the normalized kind string for whitespace tokens."
  @spec kind() :: String.t()
  def kind, do: @kind

  @type t :: %__MODULE__{
          kind: String.t(),
          content: String.t(),
          line: non_neg_integer() | nil,
          col: non_neg_integer() | nil
        }
end

defmodule CodeQA.AST.Lexing.NewlineToken do
  @moduledoc """
  A newline token emitted by `TokenNormalizer.normalize_structural/1`.

  Represents a `\\n` line boundary between two source lines.

  ## Fields

  - `kind`    — always `"<NL>"`.
  - `content` — the original newline character (`"\\n"`).
  - `line`    — 1-based line number of the line that ends here.
  - `col`     — 0-based byte offset of the newline within that line.
  """

  @kind "<NL>"

  defstruct [:content, :line, :col, kind: @kind]

  @doc "Returns the normalized kind string for newline tokens."
  @spec kind() :: String.t()
  def kind, do: @kind

  @type t :: %__MODULE__{
          kind: String.t(),
          content: String.t(),
          line: non_neg_integer() | nil,
          col: non_neg_integer() | nil
        }
end

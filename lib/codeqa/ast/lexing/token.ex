defmodule CodeQA.AST.Lexing.Token do
  @moduledoc """
  A single token emitted by `TokenNormalizer.normalize_structural/1`.

  ## Fields

  - `value`   — normalized form used for structural comparison: `<ID>`, `<STR>`,
                `<NUM>`, `<NL>`, `<WS>`, or the literal character(s) for
                punctuation and operators.
  - `content` — original source text before normalization. Identical to `value`
                for punctuation/structural tokens; differs for identifiers,
                strings, and numbers. Enables source reconstruction and is the
                correct field to check when matching declaration keywords.
  - `line`    — 1-based line number in the source file.
  - `col`     — 0-based byte offset from the start of the line.

  String literals are emitted as `StringToken` structs, not `Token`, so that
  the `interpolations` field does not pollute the common token shape.

  ## Design notes (from tree-sitter, ctags, lizard)

  - **value vs content split** — mirrors tree-sitter's distinction between a
    node's `type` (structural kind) and its `text` (original source). `value`
    is the kind used for pattern matching and comparison; `content` is the
    original text used for reporting and reconstruction.
  - **Normalization lives in value, not content** — `content` is never modified.
    This means two tokens with different `content` but the same `value` (e.g.
    `"foo"` and `"bar"` both normalizing to `<ID>`) are structurally equivalent
    for duplicate detection but distinguishable for reporting.
  - **Line + col for precise location** — ctags records line numbers; tree-sitter
    records byte ranges. We store both line (for human-readable reporting) and
    col (for IDE navigation and sub-block start/end precision).
  - **No enforcement on line/col** — synthetic tokens created in tests may omit
    line/col. Consumers that need location data should guard for nil.
  """

  defstruct [:kind, :content, :line, :col]

  @type t :: %__MODULE__{
          kind: String.t(),
          content: String.t(),
          line: non_neg_integer() | nil,
          col: non_neg_integer() | nil
        }
end

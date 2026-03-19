defmodule CodeQA.AST.Enrichment.CompoundNode do
  @moduledoc """
  Groups semantically related typed nodes together.

  A compound node represents a complete "unit" in source code — combining
  documentation, type annotations, and implementation:

  - `docs`       — [DocNode.t()] (triple-quoted docstrings)
  - `typespecs`  — [AttributeNode.t()] (@spec, @type, etc.)
  - `code`       — [Node.t()] with type :code (implementation clauses)

  Boundaries span all constituent nodes in source order (docs → typespecs →
  code), with leading/trailing whitespace tokens stripped. Column values are
  read from the `col` field of the relevant Token structs — Node has no col
  fields.

  A bare code node with no preceding docs/typespecs is still wrapped in a
  CompoundNode (with empty `docs` and `typespecs`).
  """

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Nodes.AttributeNode

  defstruct docs: [],
            typespecs: [],
            code: [],
            start_line: nil,
            start_col: nil,
            end_line: nil,
            end_col: nil

  @type t :: %__MODULE__{
          docs: [Node.t()],
          typespecs: [AttributeNode.t()],
          code: [Node.t()],
          start_line: non_neg_integer() | nil,
          start_col: non_neg_integer() | nil,
          end_line: non_neg_integer() | nil,
          end_col: non_neg_integer() | nil
        }
end

defmodule CodeQA.AST.Nodes.Shared do
  @moduledoc """
  Shared helpers for AST node modules.

  Extracted by `mix refactor --only ExtractParametricClone` because every
  node module (`CodeNode`, `DocNode`, `FunctionNode`, `ImportNode`,
  `ModuleNode`, `TestNode`) implemented an identical `cast/1` that copies
  the same six fields from a generic `Node` into its own struct. The
  helper takes the target struct module as a parameter so a single
  implementation can populate any of them.
  """

  alias CodeQA.AST.Enrichment.Node

  @spec cast_shared(module(), Node.t()) :: struct()
  def cast_shared(target_struct, %Node{} = node),
    do:
      target_struct
      |> struct(
        tokens: node.tokens,
        line_count: node.line_count,
        children: node.children,
        start_line: node.start_line,
        end_line: node.end_line,
        label: node.label
      )
end

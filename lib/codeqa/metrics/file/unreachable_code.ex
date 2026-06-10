defmodule CodeQA.Metrics.File.UnreachableCode do
  @moduledoc """
  Detects statements that are unreachable because they follow a terminal
  statement (`return`, `raise`, `throw`, `break`, `continue`) inside the same
  indentation scope.

  Distinguishes genuine dead code from idiomatic early-return guards. A guard
  such as `if (!x) return;` is followed by code at a *shallower* indent (outside
  the guard's block), so nothing after it counts. Dead code is a terminal
  statement followed by lines at the *same or deeper* indent within its block —
  those lines can never execute.

  This is the structural signal cosine-similarity scoring on aggregate metrics
  cannot capture: a guarded return and a dead-code return have near-identical
  token and indentation profiles, differing only in the relative indent of what
  comes next.

  Line-based and language-agnostic across brace and keyword-delimited languages.
  Closing delimiters (`}`, `end`, `)`) and `case`/`switch` labels on a line of
  their own are treated as scope boundaries, not as reachable statements.
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @terminal_re ~r/^\s*(return|raise|throw|break|continue)\b/
  @inline_terminal_re ~r/\b(return|raise|throw)\b.*;?\s*$/
  @boundary_re ~r/^\s*([)\]}]|end\b|else\b|elsif\b|when\b|case\b|default\s*:|catch\b|rescue\b|finally\b)/

  @impl true
  def name, do: "unreachable_code"

  @impl true
  def keys,
    do: [
      "unreachable_after_terminal_ratio",
      "terminal_statement_count",
      "unreachable_line_count"
    ]

  @impl true
  def description,
    do: "Ratio of lines unreachable because they follow a terminal statement in the same scope."

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{lines: lines}) do
    code_lines =
      lines
      |> Enum.with_index()
      |> Enum.reject(fn {line, _} -> String.trim(line) == "" end)

    {terminal_count, unreachable_count} = scan(code_lines)
    total = length(code_lines)

    ratio = if total > 0, do: Float.round(unreachable_count / total, 4), else: 0.0

    %{
      "unreachable_after_terminal_ratio" => ratio,
      "terminal_statement_count" => terminal_count,
      "unreachable_line_count" => unreachable_count
    }
  end

  # Walks the code lines, marking lines that sit at the same-or-deeper indent
  # after a terminal statement (until a boundary at a shallower-or-equal indent
  # closes the scope) as unreachable.
  defp scan(code_lines) do
    Enum.reduce(code_lines, {0, 0, nil}, fn {line, _idx}, {terminals, unreachable, active} ->
      indent = indent_of(line)

      cond do
        # Inside an active dead-code scope: a boundary at or below the terminal's
        # indent ends it; a deeper line is unreachable.
        active != nil and reachable_again?(line, indent, active) ->
          maybe_open(line, indent, terminals, unreachable, drop_active: true)

        active != nil ->
          {terminals, unreachable + 1, active}

        true ->
          maybe_open(line, indent, terminals, unreachable, drop_active: false)
      end
    end)
    |> then(fn {terminals, unreachable, _active} -> {terminals, unreachable} end)
  end

  # Opens a new dead-code scope when the line is a block-level terminal statement
  # (not an inline guard). Inline guards keep `active` nil so following code
  # stays reachable.
  defp maybe_open(line, indent, terminals, unreachable, drop_active: drop?) do
    cond do
      block_terminal?(line) ->
        {terminals + 1, unreachable, indent}

      inline_terminal?(line) ->
        {terminals + 1, unreachable, nil}

      drop? ->
        {terminals, unreachable, nil}

      true ->
        {terminals, unreachable, nil}
    end
  end

  # A line shallower than the terminal closes its block, re-entering reachable
  # code. Siblings at the same indent after a terminal are unreachable, so only a
  # strictly-shallower indent (or a boundary token there) resets.
  defp reachable_again?(line, indent, terminal_indent) do
    indent < terminal_indent or
      (indent <= terminal_indent and String.match?(line, @boundary_re))
  end

  # A terminal that ends its line with no trailing reachable code (the statement
  # owns the rest of its block). `if (!x) return;` has the terminal mid-line
  # after a condition, so it is inline, not block-level. A line ending with net
  # unclosed brackets (`return (`) is a multi-line expression whose deeper
  # continuation lines are part of the return, not dead code — not block-level.
  defp block_terminal?(line) do
    String.match?(line, @terminal_re) and
      not String.match?(line, ~r/^\s*if\b/) and
      bracket_balance(line) <= 0
  end

  # Net opening brackets on a line: positive means the statement continues onto
  # the next line. Counts (, [, { against ), ], }.
  defp bracket_balance(line) do
    line
    |> String.graphemes()
    |> Enum.reduce(0, fn
      c, acc when c in ["(", "[", "{"] -> acc + 1
      c, acc when c in [")", "]", "}"] -> acc - 1
      _, acc -> acc
    end)
  end

  defp inline_terminal?(line) do
    String.match?(line, @inline_terminal_re) and not String.match?(line, @terminal_re)
  end

  defp indent_of(line) do
    [leading] = Regex.run(~r/^\s*/, line)
    String.length(leading)
  end
end

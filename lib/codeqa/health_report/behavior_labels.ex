defmodule CodeQA.HealthReport.BehaviorLabels do
  @moduledoc "Maps category/behavior pairs to human-readable labels and action items."

  alias CodeQA.CombinedMetrics.Scorer

  @labels %{
    {"function_design", "no_boolean_parameter"} =>
      {"Boolean parameter increases coupling", "Use separate functions or options map"},
    {"function_design", "boolean_function_has_question_mark"} =>
      {"Boolean function missing ? suffix", "Rename to use question mark convention"},
    {"function_design", "has_verb_in_name"} =>
      {"Function name lacks verb", "Use action verbs in function names"},
    {"function_design", "no_magic_numbers"} =>
      {"Magic numbers detected", "Extract constants with descriptive names"},
    {"function_design", "uses_ternary_expression"} =>
      {"Ternary expression overuse", "Use pattern matching or if/else"},
    {"code_smells", "cyclomatic_complexity_under_10"} =>
      {"High cyclomatic complexity", "Reduce branching or extract guard clauses"},
    {"code_smells", "no_deeply_nested_code"} =>
      {"Deeply nested code", "Extract helper functions to reduce nesting"},
    {"code_smells", "function_length_under_25"} =>
      {"Long function likely untestable", "Split into smaller functions"},
    {"code_smells", "no_duplicate_code"} => {"Duplicate logic detected", "Extract shared helper"},
    {"code_smells", "no_debug_print_statements"} =>
      {"Debug print left in code", "Remove `IO.puts`/`IO.inspect`/`console.log` or use a logger"},
    {"scope_and_assignment", "used_only_once"} =>
      {"Variable used only once", "Inline the expression unless the name aids readability"},
    {"consistency", "consistent_error_return_shape"} =>
      {"Mixed error-return shapes",
       "Return errors in one shape (e.g. `{:error, reason}` everywhere)"},
    {"file_structure", "single_module_per_file"} =>
      {"Multiple modules in one file", "Split into separate files"},
    {"file_structure", "file_length_under_300"} =>
      {"File too long", "Split into focused modules"},
    {"dependencies", "no_circular_dependencies"} =>
      {"Circular dependency detected", "Reorganize module boundaries"},
    {"error_handling", "uses_tagged_tuples"} =>
      {"Missing tagged tuple returns", "Use {:ok, val} / {:error, reason} pattern"},
    {"naming_conventions", "filename_matches_module"} =>
      {"Filename doesn't match module", "Rename file to match module"},
    {"scope_and_assignment", "no_unused_variables"} =>
      {"Unused variables", "Remove or prefix with underscore"},
    {"testing", "test_file_exists"} => {"Missing test file", "Add tests for this module"},
    {"documentation", "has_moduledoc"} => {"Missing @moduledoc", "Add module documentation"}
  }

  @spec label(String.t(), String.t()) :: String.t()
  def label(category, behavior) do
    case Map.get(@labels, {category, behavior}) do
      {label, _action} -> label
      nil -> humanize(behavior)
    end
  end

  @spec action(String.t(), String.t()) :: String.t()
  def action(category, behavior) do
    case Map.get(@labels, {category, behavior}) do
      {_label, action} -> action
      nil -> fix_hint_fallback(category, behavior)
    end
  end

  defp fix_hint_fallback(category, behavior) do
    Scorer.all_yamls()
    |> Enum.find_value(fn {yaml_path, data} ->
      cat = yaml_path |> Path.basename() |> String.trim_trailing(".yml")
      if cat == category, do: get_in(data, [behavior, "_fix_hint"])
    end) || "Review this code block"
  end

  defp humanize(behavior),
    do:
      behavior
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
end

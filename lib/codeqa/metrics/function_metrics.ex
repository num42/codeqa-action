defmodule CodeQA.Metrics.FunctionMetrics do
  @moduledoc """
  Estimates function-level structure metrics from source text.

  Detects function definitions via language-specific patterns and measures
  average/maximum function length and parameter count. Long functions and
  many parameters signal poor decomposition and reduced maintainability.

  Covers:
  - Python/Ruby: `def` keyword
  - Elixir: `def`, `defp`, `defmacro`, `defmacrop`, `defguard`, `defdelegate`
  - JavaScript: named `function` declarations
  - C#: lines starting with access modifiers (`public`, `private`, etc.)
  """

  @behaviour CodeQA.Metrics.FileMetric

  # Python, Ruby, Elixir: `def` family
  # JavaScript: `function`
  # Go: `func`
  # Rust: `fn`
  # PHP: `function`, `fn`
  # Swift: `func`
  # Kotlin: `fun`
  @func_keyword_list ~w[def defp defmacro defmacrop defguard defdelegate function func fun fn]
  @func_keyword_re ~r/^\s*(?:async\s+|pub\s+(?:async\s+)?)?(?:def|defp|defmacro|defmacrop|defguard|defdelegate|function|func|fun|fn)\b/

  # C# / Java: access modifier + optional modifiers + return type + method name + (
  # e.g. `public async Task<int> Calculate(` or `private static String helper(`
  @access_modifier_list ~w[public private protected internal]
  @csharp_method_re ~r/^\s*(?:public|private|protected|internal)(?:\s+(?:static|virtual|override|abstract|async|sealed|new|final|synchronized|native))*\s+\S+\s+\w+\s*\(/

  @doc "Returns the list of function-definition keywords matched at line start."
  def func_keywords, do: @func_keyword_list

  @doc "Returns the list of access modifiers used for C#/Java method detection."
  def access_modifiers, do: @access_modifier_list

  @impl true
  def name, do: "function_metrics"

  @impl true
  def analyze(%{lines: lines}) do
    lines_list = Tuple.to_list(lines)
    total = length(lines_list)

    {func_indices, param_counts} =
      lines_list
      |> Enum.with_index()
      |> Enum.filter(fn {line, _} ->
        Regex.match?(@func_keyword_re, line) or Regex.match?(@csharp_method_re, line)
      end)
      |> Enum.map(fn {line, idx} -> {idx, count_params(line)} end)
      |> Enum.unzip()

    if func_indices == [] do
      %{
        "avg_function_lines" => 0.0,
        "max_function_lines" => 0,
        "avg_param_count" => 0.0,
        "max_param_count" => 0
      }
    else
      lengths =
        (func_indices ++ [total])
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> b - a end)

      n = length(lengths)
      avg_len = Float.round(Enum.sum(lengths) / n, 4)
      max_len = Enum.max(lengths)

      n_p = length(param_counts)
      avg_params = Float.round(Enum.sum(param_counts) / n_p, 4)
      max_params = Enum.max(param_counts)

      %{
        "avg_function_lines" => avg_len,
        "max_function_lines" => max_len,
        "avg_param_count" => avg_params,
        "max_param_count" => max_params
      }
    end
  end

  defp count_params(line) do
    case Regex.run(~r/\(([^)]*)\)/, line) do
      [_, args] ->
        args = String.trim(args)
        if args == "", do: 0, else: length(String.split(args, ","))

      _ ->
        0
    end
  end
end

defmodule CodeQA.Metrics.Halstead do
  @moduledoc false

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "halstead"

  @operator_re ~r/\b(?:if|else|elif|for|while|do|return|break|continue|import|from|class|def|lambda|yield|pass|raise|try|except|finally|with|as|and|or|not|in|is)\b|(?:==|!=|<=|>=|\+=|-=|\*=|\/=|\/\/=|%=|&=|\|=|\^=|\*\*=|<<=|>>=|->|:=|\.\.\.)|[+\-*\/%&|^~<>=!(){}\[\];:,.]/

  @operand_re ~r/\b[a-zA-Z_]\w*\b|\b\d+\.?\d*(?:[eE][+-]?\d+)?\b|"[^"]*"|'[^']*'/u

  @operator_keywords MapSet.new(~w[
    if else elif for while do return break continue import from class def
    lambda yield pass raise try except finally with as and or not in is
  ])

  @impl true
  def analyze(%{content: content}) when content == "" or content == nil do
    zero_result()
  end

  def analyze(%{content: content}) do
    content = String.trim(content)
    if content == "", do: zero_result(), else: compute(content)
  end

  defp compute(content) do
    operators = scan_frequencies(@operator_re, content)

    operands =
      @operand_re
      |> scan_frequencies(content)
      |> Map.reject(fn {k, _v} -> MapSet.member?(@operator_keywords, k) end)

    n1 = map_size(operators)
    n2 = map_size(operands)
    big_n1 = operators |> Map.values() |> Enum.sum()
    big_n2 = operands |> Map.values() |> Enum.sum()
    vocabulary = n1 + n2
    length = big_n1 + big_n2

    if vocabulary <= 1 do
      base_result(n1, n2, big_n1, big_n2, vocabulary, length)
    else
      volume = length * :math.log2(vocabulary)
      difficulty = if n2 > 0, do: n1 / 2 * (big_n2 / n2), else: 0.0
      effort = difficulty * volume
      estimated_bugs = volume / 3000
      time_to_implement_seconds = effort / 18

      %{
        "n1_unique_operators" => n1,
        "n2_unique_operands" => n2,
        "N1_total_operators" => big_n1,
        "N2_total_operands" => big_n2,
        "vocabulary" => vocabulary,
        "length" => length,
        "volume" => volume,
        "difficulty" => difficulty,
        "effort" => effort,
        "estimated_bugs" => estimated_bugs,
        "time_to_implement_seconds" => time_to_implement_seconds
      }
    end
  end

  defp scan_frequencies(regex, content) do
    regex |> Regex.scan(content) |> List.flatten() |> Enum.frequencies()
  end

  defp zero_result do
    %{
      "n1_unique_operators" => 0,
      "n2_unique_operands" => 0,
      "N1_total_operators" => 0,
      "N2_total_operands" => 0,
      "vocabulary" => 0,
      "length" => 0,
      "volume" => 0.0,
      "difficulty" => 0.0,
      "effort" => 0.0,
      "estimated_bugs" => 0.0
    }
  end

  defp base_result(n1, n2, big_n1, big_n2, vocabulary, length) do
    %{
      "n1_unique_operators" => n1,
      "n2_unique_operands" => n2,
      "N1_total_operators" => big_n1,
      "N2_total_operands" => big_n2,
      "vocabulary" => vocabulary,
      "length" => length,
      "volume" => 0.0,
      "difficulty" => 0.0,
      "effort" => 0.0,
      "estimated_bugs" => 0.0
    }
  end
end

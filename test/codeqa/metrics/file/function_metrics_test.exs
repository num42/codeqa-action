defmodule CodeQA.Metrics.File.FunctionMetricsTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.FunctionMetrics

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp analyze(code), do: FunctionMetrics.analyze(ctx(code))

  describe "analyze/1 - empty content" do
    test "returns zero values" do
      result = analyze("")
      assert result["avg_function_lines"] == 0.0
      assert result["max_function_lines"] == 0
      assert result["avg_param_count"] == 0.0
      assert result["max_param_count"] == 0
    end
  end

  describe "analyze/1 - function length" do
    test "measures lines between function definitions" do
      code = "def foo(x)\n  x\ndef bar(x)\n  x\n  x\n"
      result = analyze(code)
      assert result["avg_function_lines"] > 0
      assert result["max_function_lines"] >= result["avg_function_lines"]
    end
  end

  describe "analyze/1 - parameter count" do
    test "counts parameters from function signature" do
      result = analyze("def foo(a, b, c)\n  a\n")
      assert result["avg_param_count"] == 3.0
      assert result["max_param_count"] == 3
    end

    test "counts zero params for empty parens" do
      result = analyze("def foo()\n  nil\n")
      assert result["avg_param_count"] == 0.0
      assert result["max_param_count"] == 0
    end

    test "max_param_count reflects the most complex function" do
      code = "def foo(a)\n  a\ndef bar(a, b, c, d)\n  a\n"
      result = analyze(code)
      assert result["max_param_count"] == 4
    end
  end

  describe "analyze/1 - each function keyword is detected" do
    for keyword <- FunctionMetrics.func_keywords() do
      test "detects function starting with #{keyword}" do
        code = "#{unquote(keyword)} my_func(x) {\n  return x\n}"
        result = FunctionMetrics.analyze(Pipeline.build_file_context(code))

        assert result["avg_function_lines"] > 0,
               "expected '#{unquote(keyword)}' to be detected as function start"
      end
    end
  end

  describe "analyze/1 - C#/Java access modifier detection" do
    for modifier <- FunctionMetrics.access_modifiers() do
      test "detects method starting with #{modifier}" do
        code = "#{unquote(modifier)} void MyMethod() {\n  return;\n}"
        result = FunctionMetrics.analyze(Pipeline.build_file_context(code))

        assert result["avg_function_lines"] > 0,
               "expected '#{unquote(modifier)}' access modifier to trigger method detection"
      end
    end
  end
end

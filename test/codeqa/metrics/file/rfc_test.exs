defmodule CodeQA.Metrics.File.RFCTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.RFC

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: RFC.analyze(ctx(code))

  describe "analyze/1" do
    test "returns zero counts for empty content" do
      r = result("")
      assert r["rfc_count"] == 0
      assert r["rfc_density"] == 0.0
    end

    test "counts function definitions with no calls" do
      code = """
      def foo do
        1
      end
      """

      r = result(code)
      assert r["function_def_count"] == 1
      assert r["distinct_call_count"] == 0
      assert r["rfc_count"] == 1
    end

    test "counts distinct call targets" do
      code = """
      def foo do
        bar()
        baz()
        bar()
      end
      """

      r = result(code)
      # bar and baz are distinct call targets (bar appears twice but counts once)
      assert r["distinct_call_count"] == 2
      assert r["function_def_count"] == 1
      assert r["rfc_count"] == 3
    end

    test "rfc_density is rfc_count normalized by line count" do
      code = """
      def foo do
        bar()
        baz()
      end
      """

      c = ctx(code)
      r = RFC.analyze(c)
      assert r["rfc_density"] == Float.round(r["rfc_count"] / c.line_count, 4)
    end

    test "file with no functions and no calls returns all zeros" do
      r = result("x = 1\ny = 2")
      assert r["rfc_count"] == 0
      assert r["function_def_count"] == 0
      assert r["distinct_call_count"] == 0
    end

    test "file with only calls and no function definitions" do
      code = "foo()\nbar()\nbaz()"
      r = result(code)
      assert r["function_def_count"] == 0
      assert r["distinct_call_count"] == 3
      assert r["rfc_count"] == 3
    end

    test "duplicate calls are deduplicated" do
      code = "foo()\nfoo()\nfoo()"
      r = result(code)
      assert r["distinct_call_count"] == 1
    end

    test "multiple function definitions are counted" do
      code = """
      def foo do
        bar()
      end

      def baz do
        qux()
      end
      """

      r = result(code)
      assert r["function_def_count"] == 2
      assert r["distinct_call_count"] == 2
      assert r["rfc_count"] == 4
    end
  end
end

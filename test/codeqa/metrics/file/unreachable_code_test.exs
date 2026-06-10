defmodule CodeQA.Metrics.File.UnreachableCodeTest do
  use ExUnit.Case, async: true

  alias CodeQA.Metrics.File.UnreachableCode

  defp analyze(src) do
    UnreachableCode.analyze(%{lines: String.split(src, "\n")})
  end

  describe "early-return guards (reachable)" do
    test "inline guard followed by shallower code is not flagged" do
      src = """
      function f(x) {
        if (!x) return;
        doWork(x);
        return x;
      }
      """

      assert %{"unreachable_line_count" => 0, "unreachable_after_terminal_ratio" => +0.0} =
               analyze(src)
    end

    test "guard inside a hook with trailing setup is not flagged" do
      src = """
      mounted() {
        this.target = document.getElementById(this.el.dataset.target);
        if (!this.target) return;

        this.update();
        this.observer.observe(this.target);
      }
      """

      assert %{"unreachable_line_count" => 0} = analyze(src)
    end
  end

  describe "genuine dead code (unreachable)" do
    test "statements after a block-level return are flagged" do
      src = """
      function f(x) {
        return x;
        console.log("never runs");
        cleanup();
      }
      """

      result = analyze(src)
      assert result["unreachable_line_count"] == 2
      assert result["unreachable_after_terminal_ratio"] > 0.0
    end

    test "dead code inside a guard block is flagged" do
      src = """
      function f(x) {
        if (!x) {
          return;
          recover();
        }
        doWork(x);
      }
      """

      assert %{"unreachable_line_count" => 1} = analyze(src)
    end
  end

  describe "multi-line return expressions (reachable)" do
    test "return with a parenthesized continuation on deeper lines is not flagged" do
      src = """
      function hitTest(node, wx, wy) {
        if (isBrandItem(node)) {
          return (
            Math.abs(wx - node.x) <= BRAND_ITEM_HALF_W &&
            Math.abs(wy - node.y) <= BRAND_ITEM_HALF_H
          )
        }
        return node.x === wx;
      }
      """

      assert %{"unreachable_line_count" => 0} = analyze(src)
    end
  end

  describe "edge cases" do
    test "empty content yields zero" do
      assert %{"unreachable_after_terminal_ratio" => +0.0, "terminal_statement_count" => 0} =
               analyze("")
    end

    test "no terminal statements yields zero" do
      src = """
      function f(x) {
        const y = x + 1;
        doWork(y);
      }
      """

      assert %{"terminal_statement_count" => 0, "unreachable_line_count" => 0} = analyze(src)
    end
  end
end

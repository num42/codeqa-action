defmodule CodeQA.HealthReport.Formatter.AgentActionsTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Formatter.AgentActions

  defp block(severity, overrides \\ %{}) do
    Map.merge(
      %{
        path: "lib/foo.ex",
        start_line: 12,
        end_line: 40,
        language: "elixir",
        source: "def process(x) do\n  x\nend",
        potentials: [
          %{
            severity: severity,
            category: "code_smells",
            behavior: "function_length_under_25",
            cosine_delta: 0.4,
            fix_hint: nil
          }
        ]
      },
      overrides
    )
  end

  defp report(top_blocks, extra \\ %{}) do
    Map.merge(
      %{metadata: %{path: "/repo", timestamp: "2026-06-06T00:00:00Z"}, top_blocks: top_blocks},
      extra
    )
  end

  describe "frontmatter" do
    test "carries run metadata and severity counts" do
      result = AgentActions.render(report([block(:critical), block(:high)]))

      assert result =~ "---\nkind: refactoring-tasks"
      assert result =~ "path: /repo"
      assert result =~ "timestamp: 2026-06-06T00:00:00Z"
      assert result =~ "task_count: 2"
      assert result =~ "critical: 1"
      assert result =~ "high: 1"
    end

    test "includes overall grade when present" do
      result =
        AgentActions.render(report([block(:critical)], %{overall_grade: "C", overall_score: 58}))

      assert result =~ "overall_grade: C"
      assert result =~ "overall_score: 58"
    end

    test "omits metadata fields that are absent" do
      result = AgentActions.render(%{top_blocks: [block(:critical)]})

      refute result =~ "path:"
      refute result =~ "overall_grade:"
    end
  end

  describe "task body" do
    test "renders only critical and high blocks, dropping medium" do
      result = AgentActions.render(report([block(:critical), block(:medium), block(:high)]))

      assert result =~ "task_count: 2"
      assert result =~ "## 1."
      assert result =~ "## 2."
      refute result =~ "## 3."
    end

    test "orders tasks critical before high" do
      result =
        AgentActions.render(
          report([block(:high, %{path: "lib/b.ex"}), block(:critical, %{path: "lib/a.ex"})])
        )

      crit_idx = :binary.match(result, "**Severity:** critical") |> elem(0)
      high_idx = :binary.match(result, "**Severity:** high") |> elem(0)
      assert crit_idx < high_idx
    end

    test "uses fix_hint over the behavior default action when present" do
      blk =
        block(:critical, %{
          potentials: [
            %{
              severity: :critical,
              category: "x",
              behavior: "y",
              cosine_delta: 0.3,
              fix_hint: "Custom hint here"
            }
          ]
        })

      result = AgentActions.render(report([blk]))

      assert result =~ "Custom hint here"
    end

    test "renders source in a language-tagged fence" do
      result = AgentActions.render(report([block(:critical)]))

      assert result =~ "```elixir"
      assert result =~ "def process(x) do"
    end

    test "notes when source is unavailable" do
      result = AgentActions.render(report([block(:critical, %{source: nil})]))

      assert result =~ "Source code not available"
    end
  end

  describe "empty" do
    test "shows an all-clear message when no actionable blocks" do
      result = AgentActions.render(report([block(:medium)]))

      assert result =~ "task_count: 0"
      assert result =~ "No critical or high-severity blocks need attention"
    end

    test "handles a missing top_blocks key" do
      result = AgentActions.render(%{metadata: %{}})

      assert result =~ "task_count: 0"
    end
  end
end

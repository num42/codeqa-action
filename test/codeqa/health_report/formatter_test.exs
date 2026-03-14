defmodule CodeQA.HealthReport.FormatterTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Formatter

  @sample_report %{
    metadata: %{path: "/home/user/project", timestamp: "2026-03-11T00:00:00Z", total_files: 42},
    overall_score: 79,
    overall_grade: "B+",
    categories: [
      %{
        name: "Readability",
        key: :readability,
        score: 100,
        grade: "A",
        summary: "Excellent",
        metric_scores: [
          %{name: "flesch_adapted", source: "readability", weight: 0.4, good: :high, value: 102.5, score: 100}
        ],
        worst_offenders: [
          %{path: "lib/foo.ex", score: 75, grade: "B+", lines: 120, bytes: 3840,
            metric_scores: [%{name: "flesch_adapted", source: "readability", good: :high, value: 65.0, score: 75}]}
        ]
      },
      %{
        name: "Complexity",
        key: :complexity,
        score: 35,
        grade: "D",
        summary: "Critical — requires attention",
        metric_scores: [
          %{name: "difficulty", source: "halstead", weight: 0.35, value: 24.01, score: 65}
        ],
        worst_offenders: []
      }
    ]
  }

  describe "format_markdown/3 with :plain format" do
    test "produces header with # Code Health Report" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "# Code Health Report"
    end

    test "includes metadata line" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "> /home/user/project"
      assert result =~ "42 files analyzed"
    end

    test "includes overall grade" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "## Overall: B+"
    end

    test "includes category table" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "| Readability | A | 100 | Excellent |"
      assert result =~ "| Complexity | D | 35 |"
    end

    test "includes worst offenders section" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "### Worst Offenders"
      refute result =~ "lib/<br>`foo.ex`"
      assert result =~ "`lib/foo.ex`"
      assert result =~ "120 lines · 3.8 KB"
      assert result =~ "↑ flesch_adapted=65.00 (avg: 102.50)"
      refute result =~ "↑ flesch_adapted=65.00, "
    end

    test "summary detail omits category sections" do
      result = Formatter.format_markdown(@sample_report, :summary, :plain)
      refute result =~ "### Worst Offenders"
      refute result =~ "Codebase averages"
    end
  end

  describe "format_markdown/3 defaults to :plain" do
    test "two-arity call matches plain output" do
      plain = Formatter.format_markdown(@sample_report, :default, :plain)
      default = Formatter.format_markdown(@sample_report, :default)
      assert plain == default
    end
  end

  describe "format_markdown/3 with :github format" do
    test "uses emoji header with score" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      assert result =~ "## 🟡 Code Health: B+"
      assert result =~ "(79/100)"
    end

    test "includes mermaid chart" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      assert result =~ "```mermaid"
      assert result =~ "xychart-beta"
      assert result =~ "bar [100, 35]"
    end

    test "includes unicode progress bars" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      assert result =~ "████████████████████"
      assert result =~ "███████░░░░░░░░░░░░░"
    end

    test "includes grade emoji" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      assert result =~ "🟢"
      assert result =~ "🔴"
    end

    test "wraps categories in details/summary" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      assert result =~ "<details>"
      assert result =~ "<summary>"
      assert result =~ "</details>"
    end

    test "summary detail omits category details but keeps chart and bars" do
      result = Formatter.format_markdown(@sample_report, :summary, :github)
      assert result =~ "```mermaid"
      assert result =~ "████"
      refute result =~ "<details>"
    end

    test "does not include ## Overall: line (plain format header)" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      refute result =~ "## Overall: B+"
    end
  end

  describe "format_markdown/4 with :github format and chart: false" do
    test "omits mermaid chart when chart option is false" do
      result = Formatter.format_markdown(@sample_report, :default, :github, chart: false)
      refute result =~ "```mermaid"
      assert result =~ "████"
    end
  end
end

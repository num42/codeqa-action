defmodule CodeQA.HealthReport.FormatterTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Formatter

  @sample_report %{
    metadata: %{path: "/home/user/project", timestamp: "2026-03-11T00:00:00Z", total_files: 42},
    overall_score: 79,
    overall_grade: "B+",
    categories: [
      %{
        type: :threshold,
        name: "Readability",
        key: :readability,
        score: 100,
        grade: "A",
        impact: 3,
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
        type: :threshold,
        name: "Complexity",
        key: :complexity,
        score: 35,
        grade: "D",
        impact: 5,
        summary: "Critical — requires attention",
        metric_scores: [
          %{name: "difficulty", source: "halstead", weight: 0.35, value: 24.01, score: 65}
        ],
        worst_offenders: []
      }
    ]
  }

  @cosine_category %{
    type: :cosine,
    key: "function_design",
    name: "Function Design",
    score: 64,
    grade: "C",
    impact: 1,
    behaviors: [
      %{
        behavior: "no_boolean_parameter",
        cosine: 0.12,
        score: 56,
        grade: "C",
        worst_offenders: [
          %{file: "lib/foo/bar.ex", cosine: -0.71}
        ]
      },
      %{
        behavior: "single_responsibility",
        cosine: 0.45,
        score: 78,
        grade: "B+",
        worst_offenders: []
      }
    ]
  }

  @report_with_cosine %{
    @sample_report
    | categories: @sample_report.categories ++ [@cosine_category]
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

    test "includes cosine legend" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "cosine similarity"
      assert result =~ "anti-pattern detected"
    end

    test "includes category table with Impact column" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      assert result =~ "| Category | Grade | Score | Impact | Summary |"
      assert result =~ "| Readability | A | 100 | 3 | Excellent |"
      assert result =~ "| Complexity | D | 35 | 5 |"
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

  describe "format_markdown/3 plain with cosine category" do
    test "renders cosine category header" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :plain)
      assert result =~ "## Function Design — C"
    end

    test "renders cosine behavior table" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :plain)
      assert result =~ "| Behavior | Cosine | Score | Grade |"
      assert result =~ "| no_boolean_parameter | 0.12 | 56 | C |"
      assert result =~ "| single_responsibility | 0.45 | 78 | B+ |"
    end

    test "renders cosine worst offenders per behavior" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :plain)
      assert result =~ "### Worst Offenders: no_boolean_parameter"
      assert result =~ "| File | Cosine |"
      assert result =~ "| `lib/foo/bar.ex` | -0.71 |"
    end

    test "omits behaviors with no worst offenders" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :plain)
      refute result =~ "### Worst Offenders: single_responsibility"
    end

    test "cosine category impact shown in overall table" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :plain)
      assert result =~ "| Function Design | C | 64 | 1 |"
    end

    test "summary detail omits cosine worst offenders" do
      result = Formatter.format_markdown(@report_with_cosine, :summary, :plain)
      refute result =~ "### Worst Offenders: no_boolean_parameter"
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

    test "includes cosine legend" do
      result = Formatter.format_markdown(@sample_report, :default, :github)
      assert result =~ "cosine similarity"
      assert result =~ "anti-pattern detected"
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

  describe "format_markdown/3 github with cosine category" do
    test "wraps cosine category in details/summary block" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :github)
      assert result =~ "<summary><strong>🟠 Function Design — C (64/100)</strong></summary>"
    end

    test "renders cosine behaviors table inside details" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :github)
      assert result =~ "| Behavior | Cosine | Score | Grade |"
      assert result =~ "| no_boolean_parameter | 0.12 | 56 | C |"
    end

    test "renders cosine worst offenders per behavior" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :github)
      assert result =~ "**Worst Offenders: no_boolean_parameter**"
      assert result =~ "| File | Cosine |"
      assert result =~ "| `lib/foo/bar.ex` | -0.71 |"
    end

    test "omits behaviors with no worst offenders" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :github)
      refute result =~ "**Worst Offenders: single_responsibility**"
    end

    test "summary detail omits cosine worst offenders" do
      result = Formatter.format_markdown(@report_with_cosine, :summary, :github)
      refute result =~ "**Worst Offenders: no_boolean_parameter**"
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

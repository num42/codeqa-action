defmodule CodeQA.HealthReport.FormatterTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Formatter

  @sample_report %{
    categories: [
      %{
        grade: "A",
        impact: 3,
        key: :readability,
        metric_scores: [
          %{
            good: :high,
            name: "flesch_adapted",
            score: 100,
            source: "readability",
            value: 102.5,
            weight: 0.4
          }
        ],
        name: "Readability",
        score: 100,
        summary: "Excellent",
        type: :threshold,
        worst_offenders: [
          %{
            bytes: 3840,
            grade: "B+",
            lines: 120,
            metric_scores: [
              %{
                good: :high,
                name: "flesch_adapted",
                score: 75,
                source: "readability",
                value: 65.0
              }
            ],
            path: "lib/foo.ex",
            score: 75
          }
        ]
      },
      %{
        grade: "D",
        impact: 5,
        key: :complexity,
        metric_scores: [
          %{name: "difficulty", score: 65, source: "halstead", value: 24.01, weight: 0.35}
        ],
        name: "Complexity",
        score: 35,
        summary: "Critical — requires attention",
        type: :threshold,
        worst_offenders: []
      }
    ],
    metadata: %{path: "/home/user/project", timestamp: "2026-03-11T00:00:00Z", total_files: 42},
    overall_grade: "B+",
    overall_score: 79
  }

  @cosine_category %{
    behaviors: [
      %{
        behavior: "no_boolean_parameter",
        cosine: 0.12,
        grade: "C",
        score: 56,
        worst_offenders: [
          %{cosine: -0.71, file: "lib/foo/bar.ex"}
        ]
      },
      %{
        behavior: "single_responsibility",
        cosine: 0.45,
        grade: "B+",
        score: 78,
        worst_offenders: []
      }
    ],
    grade: "C",
    impact: 1,
    key: "function_design",
    name: "Function Design",
    score: 64,
    type: :cosine
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

    test "summary detail omits category sections" do
      result = Formatter.format_markdown(@sample_report, :summary, :plain)
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

    test "cosine category impact shown in overall table" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :plain)
      assert result =~ "| Function Design | C | 64 | 1 |"
    end
  end

  describe "plain formatter: PR summary section" do
    @sample_report_with_pr Map.put(@sample_report, :pr_summary, %{
                             base_grade: "B+",
                             base_score: 85,
                             blocks_flagged: 6,
                             files_added: 1,
                             files_changed: 3,
                             files_modified: 2,
                             head_grade: "C+",
                             head_score: 77,
                             score_delta: -8
                           })

    test "renders PR summary line when pr_summary present" do
      result = Formatter.format_markdown(@sample_report_with_pr, :default, :plain)
      assert result =~ "B+"
      assert result =~ "C+"
      assert result =~ "-8"
      assert result =~ "6"
      assert result =~ "1 added"
      assert result =~ "2 modified"
    end

    test "omits PR summary when pr_summary is nil" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      refute result =~ "Score:"
    end
  end

  describe "plain formatter: delta section" do
    @delta %{
      base: %{
        aggregate: %{
          "readability" => %{"mean_flesch_adapted" => 65.0},
          "halstead" => %{"mean_difficulty" => 12.0}
        }
      },
      head: %{
        aggregate: %{
          "readability" => %{"mean_flesch_adapted" => 61.0},
          "halstead" => %{"mean_difficulty" => 15.0}
        }
      }
    }

    @sample_report_with_delta Map.put(@sample_report, :codebase_delta, @delta)

    test "renders metric changes table when codebase_delta present" do
      result = Formatter.format_markdown(@sample_report_with_delta, :default, :plain)
      assert result =~ "Metric Changes"
      assert result =~ "Readability"
      assert result =~ "65.00"
      assert result =~ "61.00"
    end

    test "omits delta section when codebase_delta is nil" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      refute result =~ "Metric Changes"
    end
  end

  describe "plain formatter: agent-actions section (view :both)" do
    @block_potential %{
      behavior: "cyclomatic_complexity_under_10",
      category: "function_design",
      cosine_delta: 0.41,
      fix_hint: "Reduce branching",
      severity: :critical
    }

    @top_blocks [
      %{
        end_line: 67,
        language: "elixir",
        path: "lib/foo.ex",
        potentials: [@block_potential],
        source: "def foo do\n  :bar\nend",
        start_line: 42,
        status: "modified",
        token_count: 84,
        type: "code"
      }
    ]

    @sample_report_with_blocks Map.put(@sample_report, :top_blocks, @top_blocks)

    test "appends the refactoring-tasks frontmatter and body" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "kind: refactoring-tasks"
      assert result =~ "# Refactoring Tasks"
      assert result =~ "lib/foo.ex:42-67"
    end

    test "renders severity, behavior and fix hint as a task" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "**Severity:** critical"
      assert result =~ "function_design/cyclomatic_complexity_under_10"
      assert result =~ "Reduce branching"
    end

    test "renders source code in a fenced block" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "```elixir"
      assert result =~ "def foo do"
      assert result =~ ":bar"
    end

    test "shows the all-clear body when no actionable blocks" do
      report = Map.put(@sample_report, :top_blocks, [])
      result = Formatter.format_markdown(report, :default, :plain)
      assert result =~ "No critical or high-severity blocks need attention"
    end

    test ":metrics view omits the agent-actions section entirely" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain, :metrics)
      refute result =~ "kind: refactoring-tasks"
      refute result =~ "# Refactoring Tasks"
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
  end

  describe "Github.render with chart: false" do
    alias CodeQA.HealthReport.Formatter.Github

    test "omits mermaid chart when chart option is false" do
      result = Github.render(@sample_report, :default, [chart: false], :both)
      refute result =~ "```mermaid"
      assert result =~ "████"
    end
  end

  describe "github formatter: agent-actions section (view :both)" do
    @block_potential %{
      behavior: "cyclomatic_complexity_under_10",
      category: "function_design",
      cosine_delta: 0.41,
      fix_hint: "Reduce branching",
      severity: :critical
    }

    @top_blocks_gh [
      %{
        end_line: 67,
        language: "elixir",
        path: "lib/foo.ex",
        potentials: [@block_potential],
        source: "def foo do\n  :bar\nend",
        start_line: 42,
        status: "modified",
        token_count: 84,
        type: "code"
      }
    ]

    @report_with_blocks_gh Map.put(@sample_report, :top_blocks, @top_blocks_gh)

    test "appends the refactoring-tasks prompt after the metric sections" do
      result = Formatter.format_markdown(@report_with_blocks_gh, :default, :github)
      assert result =~ "kind: refactoring-tasks"
      assert result =~ "# Refactoring Tasks"
      assert result =~ "lib/foo.ex:42-67"
    end

    test "renders severity, behavior and fix hint as a task" do
      result = Formatter.format_markdown(@report_with_blocks_gh, :default, :github)
      assert result =~ "**Severity:** critical"
      assert result =~ "function_design/cyclomatic_complexity_under_10"
      assert result =~ "Reduce branching"
    end

    test ":metrics view omits the agent-actions section" do
      result = Formatter.format_markdown(@report_with_blocks_gh, :default, :github, :metrics)
      refute result =~ "kind: refactoring-tasks"
    end
  end

  describe "github formatter: PR summary and delta" do
    @pr_summary_gh %{
      base_grade: "B+",
      base_score: 85,
      blocks_flagged: 6,
      files_added: 1,
      files_changed: 3,
      files_modified: 2,
      head_grade: "C+",
      head_score: 77,
      score_delta: -8
    }

    @delta_gh %{
      base: %{aggregate: %{"readability" => %{"mean_flesch_adapted" => 65.0}}},
      head: %{aggregate: %{"readability" => %{"mean_flesch_adapted" => 61.0}}}
    }

    test "renders PR summary" do
      report = @sample_report |> Map.put(:pr_summary, @pr_summary_gh)
      result = Formatter.format_markdown(report, :default, :github)
      assert result =~ "B+"
      assert result =~ "C+"
      assert result =~ "-8"
    end

    test "renders delta section" do
      report = @sample_report |> Map.put(:codebase_delta, @delta_gh)
      result = Formatter.format_markdown(report, :default, :github)
      assert result =~ "Metric Changes"
      assert result =~ "65.00"
      assert result =~ "61.00"
    end
  end

  describe "render_parts/2 (view :both)" do
    test "returns metric parts plus the agent-actions part" do
      parts = Formatter.render_parts(@sample_report)
      assert length(parts) == 3
    end

    test "each metric part ends with sentinel comment" do
      [part_1, part_2 | _] = Formatter.render_parts(@sample_report)
      assert part_1 =~ "<!-- codeqa-health-report-1 -->"
      assert part_2 =~ "<!-- codeqa-health-report-2 -->"
    end

    test "part 1 contains header and grade" do
      [part_1 | _] = Formatter.render_parts(@sample_report)
      assert part_1 =~ "Code Health: B+"
      assert part_1 =~ "(79/100)"
    end

    test "part 1 contains mermaid chart by default" do
      [part_1 | _] = Formatter.render_parts(@sample_report)
      assert part_1 =~ "```mermaid"
    end

    test "part 1 contains progress bars" do
      [part_1 | _] = Formatter.render_parts(@sample_report)
      assert part_1 =~ "████"
    end

    test "part 2 contains category details" do
      [_, part_2 | _] = Formatter.render_parts(@sample_report)
      assert part_2 =~ "<details>"
      assert part_2 =~ "Readability"
    end

    test "last part is the agent-actions prompt" do
      report = Map.put(@sample_report, :top_blocks, @top_blocks_gh)
      [_, _, part_3] = Formatter.render_parts(report)
      assert part_3 =~ "kind: refactoring-tasks"
      assert part_3 =~ "lib/foo.ex:42-67"
    end

    test ":metrics view returns only the metric parts" do
      parts = Formatter.render_parts(@sample_report, view: :metrics)
      assert length(parts) == 2
      refute Enum.any?(parts, &(&1 =~ "kind: refactoring-tasks"))
    end

    test ":actions view returns only the agent-actions part" do
      report = Map.put(@sample_report, :top_blocks, @top_blocks_gh)
      assert [part] = Formatter.render_parts(report, view: :actions)
      assert part =~ "kind: refactoring-tasks"
    end
  end
end

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
          %{
            name: "flesch_adapted",
            source: "readability",
            weight: 0.4,
            good: :high,
            value: 102.5,
            score: 100
          }
        ],
        worst_offenders: [
          %{
            path: "lib/foo.ex",
            score: 75,
            grade: "B+",
            lines: 120,
            bytes: 3840,
            metric_scores: [
              %{
                name: "flesch_adapted",
                source: "readability",
                good: :high,
                value: 65.0,
                score: 75
              }
            ]
          }
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

  @enriched_cosine_category %{
    type: :cosine,
    key: "function_design",
    name: "Function Design",
    score: 64,
    grade: "C",
    impact: 1,
    behaviors: [
      %{
        behavior: "no_boolean_parameter",
        cosine: -0.65,
        score: 42,
        grade: "D+",
        worst_offenders: [
          %{
            file: "lib/codeqa/formatter.ex",
            cosine: -0.65,
            top_metrics: [
              %{metric: "branching.mean_depth", contribution: -4.10},
              %{metric: "halstead.effort", contribution: -3.22}
            ],
            top_nodes: [
              %{"start_line" => 89, "type" => "block"},
              %{"start_line" => 134, "type" => "block"}
            ]
          }
        ]
      }
    ]
  }

  @enriched_threshold_category %{
    type: :threshold,
    name: "Complexity",
    key: :complexity,
    score: 32,
    grade: "F",
    impact: 5,
    summary: "Critical",
    metric_scores: [
      %{name: "difficulty", source: "halstead", weight: 0.35, good: :low, value: 39.0, score: 32}
    ],
    worst_offenders: [
      %{
        path: "lib/foo.ex",
        score: 32,
        grade: "F",
        lines: 491,
        bytes: 15_872,
        metric_scores: [
          %{name: "difficulty", source: "halstead", good: :low, value: 99.0, score: 0}
        ],
        top_nodes: [
          %{"start_line" => 201, "type" => "block"},
          %{"start_line" => 312, "type" => "block"}
        ]
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
                             base_score: 85,
                             head_score: 77,
                             score_delta: -8,
                             base_grade: "B+",
                             head_grade: "C+",
                             blocks_flagged: 6,
                             files_changed: 3,
                             files_added: 1,
                             files_modified: 2
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

  describe "plain formatter: block section" do
    @block_potential %{
      category: "function_design",
      behavior: "cyclomatic_complexity_under_10",
      cosine_delta: 0.41,
      severity: :critical,
      fix_hint: "Reduce branching"
    }

    @top_blocks [
      %{
        path: "lib/foo.ex",
        status: "modified",
        blocks: [
          %{
            start_line: 42,
            end_line: 67,
            type: "code",
            token_count: 84,
            potentials: [@block_potential]
          }
        ]
      }
    ]

    @sample_report_with_blocks Map.put(@sample_report, :top_blocks, @top_blocks)

    test "renders block section header" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "Blocks"
      assert result =~ "1 flagged"
    end

    test "renders file group with status" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "lib/foo.ex"
      assert result =~ "modified"
    end

    test "renders block location and type" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "lines 42"
      assert result =~ "67"
      assert result =~ "84 tokens"
    end

    test "renders severity icon and behavior" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "🔴"
      assert result =~ "CRITICAL"
      assert result =~ "cyclomatic_complexity_under_10"
      assert result =~ "0.41"
    end

    test "renders fix hint" do
      result = Formatter.format_markdown(@sample_report_with_blocks, :default, :plain)
      assert result =~ "Reduce branching"
    end

    test "omits block section when top_blocks is empty" do
      report = Map.put(@sample_report, :top_blocks, [])
      result = Formatter.format_markdown(report, :default, :plain)
      refute result =~ "## Blocks"
    end

    test "omits block section when top_blocks key absent" do
      result = Formatter.format_markdown(@sample_report, :default, :plain)
      refute result =~ "## Blocks"
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

    test "renders cosine worst offenders per behavior as details cards" do
      result = Formatter.format_markdown(@report_with_cosine, :default, :github)
      assert result =~ "**Worst Offenders: no_boolean_parameter**"
      assert result =~ "<code>lib/foo/bar.ex</code>"
      assert result =~ "−0.71"
      refute result =~ "| File | Cosine |"
      refute result =~ "| `lib/foo/bar.ex` |"
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

  describe "github cosine worst offender <details> cards" do
    defp report_with_enriched_cosine do
      %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 64,
        overall_grade: "C",
        categories: [@enriched_cosine_category]
      }
    end

    test "renders <details> card for each worst offender" do
      result = Formatter.format_markdown(report_with_enriched_cosine(), :default, :github)
      assert result =~ "<details>"
      assert result =~ "<code>lib/codeqa/formatter.ex</code>"
    end

    test "renders score with Unicode minus for negative cosine in card summary" do
      result = Formatter.format_markdown(report_with_enriched_cosine(), :default, :github)
      assert result =~ "<summary><code>lib/codeqa/formatter.ex</code> — −0.65</summary>"
    end

    test "renders Why row with ↓ for negative contributions" do
      result = Formatter.format_markdown(report_with_enriched_cosine(), :default, :github)
      assert result =~ "**Why:** ↓ branching.mean_depth (−4.10), ↓ halstead.effort (−3.22)"
    end

    test "renders Why row with ↑ for positive contributions" do
      category = %{
        @enriched_cosine_category
        | behaviors: [
            %{
              behavior: "no_boolean_parameter",
              cosine: 0.5,
              score: 90,
              grade: "A",
              worst_offenders: [
                %{
                  file: "lib/foo.ex",
                  cosine: 0.5,
                  top_metrics: [%{metric: "halstead.effort", contribution: 2.5}],
                  top_nodes: []
                }
              ]
            }
          ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 90,
        overall_grade: "A",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      assert result =~ "↑ halstead.effort (+2.50)"
    end

    test "omits Why row when top_metrics is empty" do
      category = %{
        @enriched_cosine_category
        | behaviors: [
            %{
              behavior: "no_boolean_parameter",
              cosine: -0.5,
              score: 42,
              grade: "D+",
              worst_offenders: [
                %{
                  file: "lib/foo.ex",
                  cosine: -0.5,
                  top_metrics: [],
                  top_nodes: [%{"start_line" => 10, "type" => "block"}]
                }
              ]
            }
          ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 42,
        overall_grade: "D+",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      refute result =~ "**Why:**"
      assert result =~ "**Where:**"
    end

    test "renders Where row as 'line N (type)'" do
      result = Formatter.format_markdown(report_with_enriched_cosine(), :default, :github)
      assert result =~ "**Where:** line 89 (block), line 134 (block)"
    end

    test "omits Where row when top_nodes is empty" do
      category = %{
        @enriched_cosine_category
        | behaviors: [
            %{
              behavior: "no_boolean_parameter",
              cosine: -0.5,
              score: 42,
              grade: "D+",
              worst_offenders: [
                %{
                  file: "lib/foo.ex",
                  cosine: -0.5,
                  top_metrics: [%{metric: "branching.mean_depth", contribution: -4.10}],
                  top_nodes: []
                }
              ]
            }
          ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 42,
        overall_grade: "D+",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      refute result =~ "**Where:**"
      assert result =~ "**Why:**"
    end

    test "omits Where row when top_nodes key is absent" do
      category = %{
        @enriched_cosine_category
        | behaviors: [
            %{
              behavior: "no_boolean_parameter",
              cosine: -0.5,
              score: 42,
              grade: "D+",
              worst_offenders: [
                %{file: "lib/foo.ex", cosine: -0.5}
              ]
            }
          ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 42,
        overall_grade: "D+",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      refute result =~ "**Where:**"
    end

    test "does not render old table format" do
      result = Formatter.format_markdown(report_with_enriched_cosine(), :default, :github)
      refute result =~ "| File | Cosine |"
    end

    test "omits Fix row when cosine fix_hint is nil" do
      category = %{
        type: :cosine,
        key: "nonexistent",
        name: "Nonexistent",
        score: 50,
        grade: "C",
        impact: 1,
        behaviors: [
          %{
            behavior: "nonexistent_behavior",
            cosine: -0.5,
            score: 42,
            grade: "D+",
            worst_offenders: [
              %{
                file: "lib/foo.ex",
                cosine: -0.5,
                top_metrics: [%{metric: "some.metric", contribution: -1.0}],
                top_nodes: []
              }
            ]
          }
        ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 42,
        overall_grade: "D+",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      refute result =~ "**Fix:**"
    end

    test "renders Fix row for cosine when hint is present" do
      category = %{
        type: :cosine,
        key: "variable_naming",
        name: "Variable Naming",
        score: 50,
        grade: "C",
        impact: 1,
        behaviors: [
          %{
            behavior: "name_is_generic",
            cosine: -0.5,
            score: 42,
            grade: "D+",
            worst_offenders: [
              %{
                file: "lib/foo.ex",
                cosine: -0.5,
                top_metrics: [%{metric: "some.metric", contribution: -1.0}],
                top_nodes: []
              }
            ]
          }
        ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 42,
        overall_grade: "D+",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      assert result =~ "**Fix:**"
    end

    test "snapshot: full enriched cosine offender card" do
      result = Formatter.format_markdown(report_with_enriched_cosine(), :default, :github)
      assert result =~ "<details>"
      assert result =~ "<summary>"
      assert result =~ "**Why:**"
      assert result =~ "↓"
      assert result =~ "**Where:**"
      assert result =~ "line"
      assert result =~ "("
      assert result =~ "</details>"
    end
  end

  describe "github threshold worst offender <details> cards" do
    defp report_with_enriched_threshold do
      %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 32,
        overall_grade: "F",
        categories: [@enriched_threshold_category]
      }
    end

    test "renders <details> card for each threshold worst offender" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      assert result =~ "<details>"
      assert result =~ "<code>lib/foo.ex</code>"
    end

    test "summary line includes lines, size and grade" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      assert result =~ "491 lines"
      assert result =~ "F (32)"
    end

    test "renders Why row with · separator for threshold metrics" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      assert result =~ "**Why:** ↓ difficulty=99.00 (avg: 39.00)"
    end

    test "renders Where row for threshold worst offenders" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      assert result =~ "**Where:** line 201 (block), line 312 (block)"
    end

    test "renders Fix row from Categories.defaults when hint available" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      assert result =~ "**Fix:** High operator/operand ratio"
    end

    test "omits Where row when top_nodes is empty" do
      category = %{
        @enriched_threshold_category
        | worst_offenders: [
            %{
              path: "lib/bar.ex",
              score: 32,
              grade: "F",
              lines: 100,
              bytes: 3000,
              metric_scores: [
                %{name: "difficulty", source: "halstead", good: :low, value: 99.0, score: 0}
              ],
              top_nodes: []
            }
          ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 32,
        overall_grade: "F",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      refute result =~ "**Where:**"
    end

    test "does not render old table format" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      refute result =~ "| File | Grade | Issues |"
    end

    test "omits Fix row when threshold fix_hint is nil" do
      category = %{
        @enriched_threshold_category
        | worst_offenders: [
            %{
              path: "lib/bar.ex",
              score: 10,
              grade: "F",
              lines: 200,
              bytes: 6000,
              metric_scores: [
                %{
                  name: "nonexistent_metric",
                  source: "nonexistent_source",
                  good: :low,
                  value: 99.0,
                  score: 10
                }
              ],
              top_nodes: []
            }
          ]
      }

      report = %{
        metadata: %{
          path: "/home/user/project",
          timestamp: "2026-03-11T00:00:00Z",
          total_files: 10
        },
        overall_score: 10,
        overall_grade: "F",
        categories: [category]
      }

      result = Formatter.format_markdown(report, :default, :github)
      refute result =~ "**Fix:**"
    end

    test "snapshot: full enriched threshold offender card" do
      result = Formatter.format_markdown(report_with_enriched_threshold(), :default, :github)
      assert result =~ "<details>"
      assert result =~ "<summary>"
      assert result =~ "**Why:**"
      assert result =~ "**Where:**"
      assert result =~ "</details>"
    end
  end
end

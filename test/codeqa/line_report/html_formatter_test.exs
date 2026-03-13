defmodule CodeQA.LineReport.HtmlFormatterTest do
  use ExUnit.Case, async: true

  alias CodeQA.LineReport.HtmlFormatter

  @sample_results %{
    "/project/lib/foo.ex" => %{
      baseline: %{
        "readability" => %{"flesch_adapted" => 45.2, "fog_adapted" => 12.1},
        "halstead" => %{"volume" => 300.0, "estimated_bugs" => 0.1}
      },
      lines: [
        %{
          line_number: 1,
          content: "defmodule Foo do",
          impact: %{
            "readability" => %{"flesch_adapted" => 2.3, "fog_adapted" => -1.1},
            "halstead" => %{"volume" => 12.4, "estimated_bugs" => -0.01}
          }
        },
        %{
          line_number: 2,
          content: "  def bar, do: :ok",
          impact: %{
            "readability" => %{"flesch_adapted" => -1.0, "fog_adapted" => 0.5},
            "halstead" => %{"volume" => 8.0, "estimated_bugs" => 0.02}
          }
        },
        %{
          line_number: 3,
          content: "end",
          impact: %{
            "readability" => %{"flesch_adapted" => 0.1, "fog_adapted" => 0.0},
            "halstead" => %{"volume" => 2.0, "estimated_bugs" => 0.0}
          }
        }
      ]
    },
    "/project/lib/bar/baz.ex" => %{
      baseline: %{
        "readability" => %{"flesch_adapted" => 60.0, "fog_adapted" => 8.0},
        "halstead" => %{"volume" => 150.0, "estimated_bugs" => 0.05}
      },
      lines: [
        %{
          line_number: 1,
          content: "defmodule Bar.Baz do",
          impact: %{
            "readability" => %{"flesch_adapted" => 1.0, "fog_adapted" => -0.5},
            "halstead" => %{"volume" => 5.0, "estimated_bugs" => 0.0}
          }
        }
      ]
    }
  }

  describe "generate/2" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "codeqa_html_test_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(tmp_dir) end)
      %{tmp_dir: tmp_dir}
    end

    test "creates output directory and index.html", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      assert File.exists?(Path.join(tmp_dir, "index.html"))
    end

    test "creates per-file HTML mirroring source directory structure", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      assert File.exists?(Path.join(tmp_dir, "lib/foo.ex.html"))
      assert File.exists?(Path.join(tmp_dir, "lib/bar/baz.ex.html"))
    end

    test "per-file HTML embeds data as JSON in window.__DATA__", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "window.__DATA__"
      # JSON contains the source line content
      assert html =~ "defmodule Foo do"
      assert html =~ "def bar, do: :ok"
      # JSON contains metric values
      assert html =~ "flesch_adapted"
      assert html =~ "volume"
    end

    test "per-file HTML embeds metric directions in window.__DIRECTIONS__", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "window.__DIRECTIONS__"
      assert html =~ "readability.flesch_adapted"
      assert html =~ ~s("high")
    end

    test "per-file HTML embeds metadata in window.__META__", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "window.__META__"
      assert html =~ "lib/foo.ex"
      assert html =~ "index.html"
    end

    test "per-file HTML is self-contained with inline styles and script", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "<!DOCTYPE html>"
      assert html =~ "<style>"
      assert html =~ "</style>"
      assert html =~ "<script>"
    end

    test "CSS includes sticky positioning for line-num and code columns", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "position: sticky"
      assert html =~ "line-num-header"
      assert html =~ "code-header"
    end

    test "CSS includes code truncation with click-to-expand", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "text-overflow: ellipsis"
      assert html =~ ".code.expanded code"
      assert html =~ "pre-wrap"
    end

    test "CSS includes metric cell truncation with click-to-expand", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ ".metric-cell.expanded"
    end

    test "JS includes column resize handles", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "resize-handle"
      assert html =~ "col-resize"
      assert html =~ "mousedown"
    end

    test "JS renders table with impactColor matching Elixir logic", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      # JS has the color function
      assert html =~ "impactColor"
      assert html =~ "rgba(40,167,69,"
      assert html =~ "rgba(220,53,69,"
    end

    test "JS renders code cells with click-to-expand", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "classList.toggle"
      assert html =~ "expanded"
    end

    test "index.html embeds file list as JSON in window.__INDEX__", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "index.html"))

      assert html =~ "window.__INDEX__"
      assert html =~ "lib/foo.ex"
      assert html =~ "lib/bar/baz.ex"
      assert html =~ "lineCount"
    end

    test "line numbers have user-select: none in CSS", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "user-select: none"
    end
  end

  describe "metric_direction/2" do
    test "returns :high for flesch_adapted from readability" do
      assert HtmlFormatter.metric_direction("readability", "flesch_adapted") == :high
    end

    test "returns :low for fog_adapted from readability" do
      assert HtmlFormatter.metric_direction("readability", "fog_adapted") == :low
    end

    test "returns :low for volume from halstead" do
      assert HtmlFormatter.metric_direction("halstead", "volume") == :low
    end

    test "defaults to :low for unknown metrics" do
      assert HtmlFormatter.metric_direction("unknown", "foo") == :low
    end
  end

  describe "computed_columns/0" do
    test "returns category definitions derived from health report categories" do
      columns = HtmlFormatter.computed_columns()

      assert is_list(columns)
      assert length(columns) > 0

      readability = Enum.find(columns, &(&1.key == "readability"))
      assert readability != nil
      assert readability.name == "Readability"
      assert length(readability.metrics) > 0

      flesch = Enum.find(readability.metrics, &(&1.name == "flesch_adapted"))
      assert flesch.source == "readability"
      assert flesch.weight == 0.4
      assert flesch.good == "high"
    end

    test "includes all six default categories" do
      columns = HtmlFormatter.computed_columns()
      keys = Enum.map(columns, & &1.key)

      assert "readability" in keys
      assert "complexity" in keys
      assert "structure" in keys
      assert "duplication" in keys
      assert "naming" in keys
      assert "magic_numbers" in keys
    end
  end

  describe "generate/2 computed columns" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "codeqa_html_test_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(tmp_dir) end)
      %{tmp_dir: tmp_dir}
    end

    test "per-file HTML embeds computed column definitions in window.__COMPUTED__", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "window.__COMPUTED__"
      assert html =~ "readability"
      assert html =~ "Readability"
      assert html =~ "flesch_adapted"
    end

    test "JS includes weight panel rendering", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "weights-panel"
      assert html =~ "weight-input"
    end

    test "JS includes computed column calculation and rendering", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "computeValue"
      assert html =~ "computed-header"
    end

    test "CSS includes computed column styling", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ ".computed-header"
      assert html =~ ".computed-cell"
    end

    test "per-file HTML embeds grade scale in window.__GRADE_SCALE__", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "window.__GRADE_SCALE__"
      assert html =~ "\"grade\""
      assert html =~ "\"min\""
    end

    test "JS includes grade cell rendering", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ "grade-cell"
      assert html =~ "grade-header"
      assert html =~ "gradeImpact"
    end

    test "CSS includes grade cell styling", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)

      html = File.read!(Path.join(tmp_dir, "lib/foo.ex.html"))

      assert html =~ ".grade-cell"
      assert html =~ ".grade-A"
      assert html =~ ".grade-F"
    end
  end

  describe "generate/3 with ref option" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "codeqa_ref_test_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(tmp_dir) end)
      %{tmp_dir: tmp_dir}
    end

    test "writes reports under reports/<ref>/ subdirectory", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      assert File.exists?(Path.join([tmp_dir, "reports", "abc1234", "lib", "foo.ex.html"]))
      assert File.exists?(Path.join([tmp_dir, "reports", "abc1234", "lib", "bar", "baz.ex.html"]))
    end

    test "does not create index.html inside reports/<ref>/", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      refute File.exists?(Path.join([tmp_dir, "reports", "abc1234", "index.html"]))
    end

    test "generates manifest.json with ref entry", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      manifest_path = Path.join(tmp_dir, "manifest.json")
      assert File.exists?(manifest_path)
      manifest = manifest_path |> File.read!() |> Jason.decode!()
      assert manifest["schemaVersion"] == 1
      assert [report] = manifest["reports"]
      assert report["ref"] == "abc1234"
      assert is_binary(report["generated_at"])
      files = report["files"]
      assert length(files) == 2
      paths = Enum.map(files, & &1["path"])
      assert "lib/foo.ex" in paths
      assert "lib/bar/baz.ex" in paths
    end

    test "manifest entry includes file metadata", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      manifest = Path.join(tmp_dir, "manifest.json") |> File.read!() |> Jason.decode!()
      [report] = manifest["reports"]
      foo = Enum.find(report["files"], &(&1["path"] == "lib/foo.ex"))
      assert foo["htmlPath"] == "lib/foo.ex.html"
      assert foo["lineCount"] == 3
      assert foo["baseline"]["readability"]["flesch_adapted"] == 45.2
    end

    test "appends to existing manifest without duplicating ref", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      manifest = Path.join(tmp_dir, "manifest.json") |> File.read!() |> Jason.decode!()
      assert length(manifest["reports"]) == 1
    end

    test "appends new ref to existing manifest", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "abc1234")
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "def5678")
      manifest = Path.join(tmp_dir, "manifest.json") |> File.read!() |> Jason.decode!()
      assert length(manifest["reports"]) == 2
      refs = Enum.map(manifest["reports"], & &1["ref"])
      assert "abc1234" in refs
      assert "def5678" in refs
    end

    test "without ref option writes directly to output_dir (backwards compat)", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir)
      assert File.exists?(Path.join([tmp_dir, "lib", "foo.ex.html"]))
      assert File.exists?(Path.join(tmp_dir, "index.html"))
      refute File.exists?(Path.join(tmp_dir, "manifest.json"))
    end

    test "max_reports prunes oldest entries from manifest", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "ref1")
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "ref2")
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "ref3")
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, max_reports: 2, ref: "ref4")

      manifest = Path.join(tmp_dir, "manifest.json") |> File.read!() |> Jason.decode!()
      assert length(manifest["reports"]) == 2
      refs = Enum.map(manifest["reports"], & &1["ref"])
      refute "ref1" in refs
      refute "ref2" in refs
      assert "ref3" in refs
      assert "ref4" in refs
    end

    test "max_reports deletes pruned report directories", %{tmp_dir: tmp_dir} do
      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "old_ref")
      assert File.exists?(Path.join([tmp_dir, "reports", "old_ref"]))

      :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "new_ref", max_reports: 1)
      refute File.exists?(Path.join([tmp_dir, "reports", "old_ref"]))
      assert File.exists?(Path.join([tmp_dir, "reports", "new_ref"]))
    end

    test "max_reports is ignored when not set", %{tmp_dir: tmp_dir} do
      for i <- 1..5 do
        :ok = HtmlFormatter.generate(@sample_results, tmp_dir, ref: "ref#{i}")
      end

      manifest = Path.join(tmp_dir, "manifest.json") |> File.read!() |> Jason.decode!()
      assert length(manifest["reports"]) == 5
    end
  end

  describe "impact_color/3" do
    test "positive impact on good:high metric is green" do
      {r, g, _b, _a} = HtmlFormatter.impact_color(5.0, :high, 10.0)
      assert g > r
    end

    test "negative impact on good:high metric is red" do
      {r, g, _b, _a} = HtmlFormatter.impact_color(-5.0, :high, 10.0)
      assert r > g
    end

    test "positive impact on good:low metric is red (line increases a bad metric)" do
      {r, g, _b, _a} = HtmlFormatter.impact_color(5.0, :low, 10.0)
      assert r > g
    end

    test "negative impact on good:low metric is green" do
      {r, g, _b, _a} = HtmlFormatter.impact_color(-5.0, :low, 10.0)
      assert g > r
    end

    test "zero impact returns transparent" do
      {_r, _g, _b, a} = HtmlFormatter.impact_color(0.0, :low, 10.0)
      assert a < 0.05
    end
  end
end

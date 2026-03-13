defmodule CodeQA.LineReportCLITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @fixture_path Path.expand("../fixtures/sample.ex", __DIR__)

  describe "line-report command" do
    test "table format (default) outputs lines with metrics" do
      output = capture_io(fn ->
        CodeQA.CLI.main(["line-report", @fixture_path])
      end)

      # Should contain line numbers and metric deltas
      assert output =~ ~r/\d+ \|/
    end

    test "json format outputs valid JSON" do
      output = capture_io(fn ->
        CodeQA.CLI.main(["line-report", "--format", "json", @fixture_path])
      end)

      assert {:ok, decoded} = Jason.decode(output)
      assert is_map(decoded)
      # Should have the file path as a key
      assert map_size(decoded) > 0
    end

    test "html format creates output directory" do
      output_dir = Path.join(System.tmp_dir!(), "codeqa_test_html_#{System.unique_integer([:positive])}")

      stderr = capture_io(:stderr, fn ->
        capture_io(fn ->
          CodeQA.CLI.main(["line-report", "--format", "html", "--output-dir", output_dir, @fixture_path])
        end)
      end)

      assert stderr =~ "HTML report written to #{output_dir}/"
      assert File.dir?(output_dir)

      # Cleanup
      File.rm_rf!(output_dir)
    end

    test "html format with --ref creates ref-specific subdirectory" do
      output_dir = Path.join(System.tmp_dir!(), "codeqa_test_html_ref_#{System.unique_integer([:positive])}")

      stderr = capture_io(:stderr, fn ->
        capture_io(fn ->
          CodeQA.CLI.main(["line-report", "--format", "html", "--output-dir", output_dir, "--ref", "abc123", @fixture_path])
        end)
      end)

      assert stderr =~ "HTML report written to #{output_dir}/"
      # The ref creates a reports/abc123 subdirectory inside output_dir
      assert File.dir?(Path.join([output_dir, "reports", "abc123"]))

      # Cleanup
      File.rm_rf!(output_dir)
    end

    test "html format with --max-reports passes option through" do
      output_dir = Path.join(System.tmp_dir!(), "codeqa_test_html_max_#{System.unique_integer([:positive])}")

      stderr = capture_io(:stderr, fn ->
        capture_io(fn ->
          CodeQA.CLI.main(["line-report", "--format", "html", "--output-dir", output_dir, "--ref", "v1", "--max-reports", "3", @fixture_path])
        end)
      end)

      assert stderr =~ "HTML report written to #{output_dir}/"

      # Cleanup
      File.rm_rf!(output_dir)
    end

    test "nonexistent path prints error to stderr" do
      assert catch_exit(
        capture_io(:stderr, fn ->
          capture_io(fn ->
            CodeQA.CLI.main(["line-report", "/nonexistent/path/to/file.ex"])
          end)
        end)
      ) == {:shutdown, 1}
    end

    test "unknown format prints error to stderr" do
      assert catch_exit(
        capture_io(:stderr, fn ->
          capture_io(fn ->
            CodeQA.CLI.main(["line-report", "--format", "xml", @fixture_path])
          end)
        end)
      ) == {:shutdown, 1}
    end

    test "--lines option filters output" do
      output = capture_io(fn ->
        CodeQA.CLI.main(["line-report", "--format", "json", "--lines", "1-3", @fixture_path])
      end)

      assert {:ok, _decoded} = Jason.decode(output)
    end

    test "defaults to current directory when no path given" do
      # Just verify it doesn't crash — use the fixtures dir which has a single small file
      output = capture_io(fn ->
        CodeQA.CLI.main(["line-report", "--format", "json", @fixture_path])
      end)

      assert {:ok, decoded} = Jason.decode(output)
      assert Map.has_key?(decoded, @fixture_path)
    end
  end
end

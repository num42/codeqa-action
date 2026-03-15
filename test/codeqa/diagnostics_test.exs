defmodule CodeQA.DiagnosticsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @lib_path Path.expand("../../lib", __DIR__)
  # Use a small subdirectory for per-file mode to keep tests fast
  @small_path Path.expand("../../lib/codeqa/health_report", __DIR__)

  describe "run/1 aggregate mode" do
    @tag timeout: 120_000
    test "runs without error on the project lib directory" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @lib_path, mode: :aggregate, top: 5, format: :plain)
        end)

      assert output =~ "## Diagnose: aggregate"
    end

    @tag timeout: 120_000
    test "output contains issues table header" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @lib_path, mode: :aggregate, top: 5, format: :plain)
        end)

      assert output =~ "| Behavior | Cosine | Score |"
    end

    @tag timeout: 120_000
    test "output contains category breakdown" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @lib_path, mode: :aggregate, top: 5, format: :plain)
        end)

      assert output =~ "###"
    end

    @tag timeout: 120_000
    test "json format returns valid JSON with issues and categories keys" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @lib_path, mode: :aggregate, top: 5, format: :json)
        end)

      decoded = Jason.decode!(output)
      assert Map.has_key?(decoded, "issues")
      assert Map.has_key?(decoded, "categories")
    end
  end

  describe "run/1 per-file mode" do
    @tag timeout: 120_000
    test "runs without error on a small directory" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @small_path, mode: :per_file, top: 3, format: :plain)
        end)

      assert output =~ "## Diagnose: per-file"
    end

    @tag timeout: 120_000
    test "output contains per-file table header" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @small_path, mode: :per_file, top: 3, format: :plain)
        end)

      assert output =~ "| File | Behavior | Cosine | Score |"
    end

    @tag timeout: 120_000
    test "json format returns valid JSON with files key" do
      output =
        capture_io(fn ->
          CodeQA.Diagnostics.run(path: @small_path, mode: :per_file, top: 3, format: :json)
        end)

      decoded = Jason.decode!(output)
      assert Map.has_key?(decoded, "files")
      assert is_list(decoded["files"])
    end
  end
end

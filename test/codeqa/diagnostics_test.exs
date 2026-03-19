defmodule CodeQA.DiagnosticsTest do
  use ExUnit.Case, async: true

  @small_path Path.expand("../../lib/codeqa/health_report/formatter", __DIR__)

  describe "run/1 aggregate mode" do
    test "plain format output structure" do
      output = CodeQA.Diagnostics.run(path: @small_path, mode: :aggregate, top: 5, format: :plain)

      assert output =~ "## Diagnose: aggregate"
      assert output =~ "| Behavior | Cosine | Score |"
      assert output =~ "###"
    end

    test "json format returns valid JSON with issues and categories keys" do
      output = CodeQA.Diagnostics.run(path: @small_path, mode: :aggregate, top: 5, format: :json)

      decoded = Jason.decode!(output)
      assert Map.has_key?(decoded, "issues")
      assert Map.has_key?(decoded, "categories")
    end
  end

  describe "run/1 per-file mode" do
    @tag timeout: 120_000
    test "runs without error on a small directory" do
      output = CodeQA.Diagnostics.run(path: @small_path, mode: :per_file, top: 3, format: :plain)

      assert output =~ "## Diagnose: per-file"
    end

    @tag timeout: 120_000
    test "output contains per-file table header" do
      output = CodeQA.Diagnostics.run(path: @small_path, mode: :per_file, top: 3, format: :plain)

      assert output =~ "| File | Behavior | Cosine | Score |"
    end

    @tag timeout: 120_000
    test "json format returns valid JSON with files key" do
      output = CodeQA.Diagnostics.run(path: @small_path, mode: :per_file, top: 3, format: :json)

      decoded = Jason.decode!(output)
      assert Map.has_key?(decoded, "files")
      assert is_list(decoded["files"])
    end
  end
end

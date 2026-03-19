defmodule CodeQA.BlockImpactAnalyzerTest do
  # async: false because the orchestrator uses Task.async_stream internally
  use ExUnit.Case, async: false

  alias CodeQA.BlockImpactAnalyzer

  @fixture_content """
  defmodule MyModule do
    def foo do
      x = 1
      y = 2
      x + y
    end

    def bar do
      :ok
    end
  end
  """

  describe "analyze/3" do
    test "adds 'nodes' key to each file entry in the pipeline result" do
      files = %{"lib/my_module.ex" => @fixture_content}
      pipeline_result = CodeQA.Engine.Analyzer.analyze_codebase(files)

      result = BlockImpactAnalyzer.analyze(pipeline_result, files)

      assert Map.has_key?(result, "files")
      assert Map.has_key?(result["files"], "lib/my_module.ex")
      file_data = result["files"]["lib/my_module.ex"]
      assert Map.has_key?(file_data, "nodes")
      assert is_list(file_data["nodes"])
    end

    test "each node has required fields" do
      files = %{"lib/my_module.ex" => @fixture_content}
      pipeline_result = CodeQA.Engine.Analyzer.analyze_codebase(files)
      result = BlockImpactAnalyzer.analyze(pipeline_result, files)

      nodes = result["files"]["lib/my_module.ex"]["nodes"]

      Enum.each(nodes, fn node ->
        assert Map.has_key?(node, "start_line")
        assert Map.has_key?(node, "column_start")
        assert Map.has_key?(node, "char_length")
        assert Map.has_key?(node, "type")
        assert Map.has_key?(node, "token_count")
        assert Map.has_key?(node, "refactoring_potentials")
        assert Map.has_key?(node, "children")
        assert is_list(node["refactoring_potentials"])
        assert is_list(node["children"])
      end)
    end

    test "nodes are sorted by start_line ascending" do
      files = %{"lib/my_module.ex" => @fixture_content}
      pipeline_result = CodeQA.Engine.Analyzer.analyze_codebase(files)
      result = BlockImpactAnalyzer.analyze(pipeline_result, files)

      nodes = result["files"]["lib/my_module.ex"]["nodes"]
      start_lines = Enum.map(nodes, & &1["start_line"])
      assert start_lines == Enum.sort(start_lines)
    end

    test "preserves existing 'codebase' key in pipeline result" do
      files = %{"lib/my_module.ex" => @fixture_content}
      pipeline_result = CodeQA.Engine.Analyzer.analyze_codebase(files)
      result = BlockImpactAnalyzer.analyze(pipeline_result, files)

      assert Map.has_key?(result, "codebase")
      assert result["codebase"] == pipeline_result["codebase"]
    end

    test "nodes_top option limits refactoring_potentials per node" do
      files = %{"lib/my_module.ex" => @fixture_content}
      pipeline_result = CodeQA.Engine.Analyzer.analyze_codebase(files)
      result = BlockImpactAnalyzer.analyze(pipeline_result, files, nodes_top: 1)

      nodes = result["files"]["lib/my_module.ex"]["nodes"]

      Enum.each(nodes, fn node ->
        assert length(node["refactoring_potentials"]) <= 1
      end)
    end
  end
end

defmodule CodeQA.HealthReport.ConfigTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Config

  @default_impact %{
    "complexity" => 5,
    "file_structure" => 4,
    "function_design" => 4,
    "code_smells" => 3,
    "naming_conventions" => 2,
    "error_handling" => 2,
    "consistency" => 2,
    "documentation" => 1,
    "testing" => 1
  }

  describe "load/1 with nil" do
    test "returns default impact map" do
      result = Config.load(nil)
      assert result.impact_map == @default_impact
    end

    test "returns combined_top of 2" do
      result = Config.load(nil)
      assert result.combined_top == 2
    end

    test "returns categories and grade_scale" do
      result = Config.load(nil)
      assert is_list(result.categories)
      assert is_list(result.grade_scale)
    end
  end

  describe "load/1 with YAML path" do
    defp write_temp_yaml(content) do
      path = Path.join(System.tmp_dir!(), "test_config_#{System.unique_integer()}.yml")
      File.write!(path, content)
      on_exit(fn -> File.rm(path) end)
      path
    end

    test "user impact values override defaults, defaults fill gaps" do
      path =
        write_temp_yaml("""
        impact:
          complexity: 10
          testing: 9
        """)

      result = Config.load(path)

      assert result.impact_map["complexity"] == 10
      assert result.impact_map["testing"] == 9
      # Default values for keys not overridden
      assert result.impact_map["file_structure"] == 4
      assert result.impact_map["function_design"] == 4
      assert result.impact_map["code_smells"] == 3
      assert result.impact_map["naming_conventions"] == 2
      assert result.impact_map["error_handling"] == 2
      assert result.impact_map["consistency"] == 2
      assert result.impact_map["documentation"] == 1
    end

    test "reads combined_top from YAML" do
      path =
        write_temp_yaml("""
        combined_top: 5
        """)

      result = Config.load(path)
      assert result.combined_top == 5
    end

    test "defaults to combined_top: 2 when absent from YAML" do
      path =
        write_temp_yaml("""
        categories: {}
        """)

      result = Config.load(path)
      assert result.combined_top == 2
    end

    test "defaults to full default impact map when impact absent from YAML" do
      path =
        write_temp_yaml("""
        categories: {}
        """)

      result = Config.load(path)
      assert result.impact_map == @default_impact
    end

    test "returns categories and grade_scale alongside impact fields" do
      path =
        write_temp_yaml("""
        impact:
          complexity: 5
        combined_top: 3
        """)

      result = Config.load(path)
      assert is_list(result.categories)
      assert is_list(result.grade_scale)
      assert is_map(result.impact_map)
      assert is_integer(result.combined_top)
    end
  end
end

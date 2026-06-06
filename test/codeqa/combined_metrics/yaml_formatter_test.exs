defmodule CodeQA.CombinedMetrics.YamlFormatterTest do
  use ExUnit.Case, async: true

  alias CodeQA.CombinedMetrics.YamlFormatter

  describe "format/1" do
    test "emits _fix_hint and survives a parse roundtrip" do
      data = %{
        "cyclomatic_complexity_under_10" => %{
          "_doc" => "Functions should stay simple.",
          "_fix_hint" => "Reduce branching in this {{line_count}}-line {{type}}.",
          "_log_baseline" => 1.5,
          "halstead" => %{"mean_difficulty" => 0.42}
        }
      }

      yaml = YamlFormatter.format(data)
      assert yaml =~ "_fix_hint:"
      assert yaml =~ "{{line_count}}"

      {:ok, parsed} = YamlElixir.read_from_string(yaml)

      assert get_in(parsed, ["cyclomatic_complexity_under_10", "_fix_hint"]) ==
               "Reduce branching in this {{line_count}}-line {{type}}."
    end

    test "emits _fix_hint before group sections" do
      data = %{
        "b" => %{
          "_fix_hint" => "Fix it.",
          "halstead" => %{"mean_difficulty" => 0.1}
        }
      }

      yaml = YamlFormatter.format(data)
      fix_hint_idx = :binary.match(yaml, "_fix_hint") |> elem(0)
      group_idx = :binary.match(yaml, "halstead") |> elem(0)
      assert fix_hint_idx < group_idx
    end
  end
end

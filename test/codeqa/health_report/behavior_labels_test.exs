defmodule CodeQA.HealthReport.BehaviorLabelsTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.BehaviorLabels

  describe "label/2" do
    test "returns human-readable label for known behavior" do
      assert BehaviorLabels.label("function_design", "no_boolean_parameter") ==
               "Boolean parameter increases coupling"
    end

    test "falls back to humanized behavior name for unknown" do
      assert BehaviorLabels.label("unknown_cat", "some_weird_behavior") ==
               "Some Weird Behavior"
    end
  end

  describe "action/2" do
    test "returns action for known behavior" do
      assert is_binary(BehaviorLabels.action("function_design", "no_boolean_parameter"))
    end

    test "falls back to fix_hint from YAML when no hardcoded action" do
      assert is_binary(BehaviorLabels.action("naming_conventions", "filename_matches_module"))
    end

    test "returns generic action for completely unknown behavior" do
      assert BehaviorLabels.action("unknown", "unknown") == "Review this code block"
    end
  end
end

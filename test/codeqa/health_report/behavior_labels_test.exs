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

    test "labels the report's most common false-positive behaviors" do
      assert BehaviorLabels.label("code_smells", "no_debug_print_statements") ==
               "Debug print left in code"

      assert BehaviorLabels.label("scope_and_assignment", "used_only_once") ==
               "Variable used only once"

      assert BehaviorLabels.label("consistency", "consistent_error_return_shape") ==
               "Mixed error-return shapes"
    end
  end

  describe "action/2" do
    test "returns action for known behavior" do
      assert is_binary(BehaviorLabels.action("function_design", "no_boolean_parameter"))
    end

    test "falls back to fix_hint from YAML when no hardcoded action" do
      assert is_binary(BehaviorLabels.action("naming_conventions", "filename_matches_module"))
    end

    test "falls back to a behavior-named action for a completely unknown behavior" do
      action = BehaviorLabels.action("unknown", "needs_descriptive_name")
      assert action =~ "Needs Descriptive Name"
      refute action == "Review this code block"
    end
  end
end

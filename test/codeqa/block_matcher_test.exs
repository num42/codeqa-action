defmodule Test.NodeMatcherTest do
  use ExUnit.Case, async: true

  alias Test.NodeMatcher

  describe "exact/2" do
    test "returns tagged tuple for :content field" do
      assert {:exact, :content, "add"} = NodeMatcher.exact(:content, "add")
    end

    test "returns tagged tuple for :value field" do
      assert {:exact, :value, "identifier"} = NodeMatcher.exact(:value, "identifier")
    end

    test "raises FunctionClauseError for unsupported field" do
      assert_raise FunctionClauseError, fn ->
        NodeMatcher.exact(:type, "something")
      end
    end
  end

  describe "partial/2" do
    test "returns tagged tuple for :content field" do
      assert {:partial, :content, "@doc"} = NodeMatcher.partial(:content, "@doc")
    end

    test "returns tagged tuple for :value field" do
      assert {:partial, :value, "doc"} = NodeMatcher.partial(:value, "doc")
    end

    test "raises FunctionClauseError for unsupported field" do
      assert_raise FunctionClauseError, fn ->
        NodeMatcher.partial(:type, "something")
      end
    end
  end
end

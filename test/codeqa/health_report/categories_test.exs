defmodule CodeQA.HealthReport.CategoriesTest do
  use ExUnit.Case

  alias CodeQA.HealthReport.Categories

  describe "defaults/0" do
    test "all metrics have fix_hint field" do
      categories = Categories.defaults()

      metrics = Enum.flat_map(categories, & &1.metrics)

      Enum.each(metrics, fn metric ->
        assert Map.has_key?(metric, :fix_hint),
               "Metric #{metric.name} missing :fix_hint field"

        assert is_binary(metric.fix_hint),
               "Metric #{metric.name} :fix_hint must be a string"

        assert String.length(metric.fix_hint) > 0,
               "Metric #{metric.name} :fix_hint cannot be empty"
      end)
    end

    test "all categories have expected keys" do
      categories = Categories.defaults()

      Enum.each(categories, fn category ->
        assert Map.has_key?(category, :key)
        assert Map.has_key?(category, :name)
        assert Map.has_key?(category, :metrics)
      end)
    end

    test "all metrics have required threshold keys" do
      categories = Categories.defaults()

      metrics = Enum.flat_map(categories, & &1.metrics)

      Enum.each(metrics, fn metric ->
        assert Map.has_key?(metric, :name)
        assert Map.has_key?(metric, :source)
        assert Map.has_key?(metric, :weight)
        assert Map.has_key?(metric, :good)
        assert Map.has_key?(metric, :thresholds)
        assert Map.has_key?(metric, :fix_hint)
      end)
    end

    test "fix_hint is accessible via Map.get" do
      categories = Categories.defaults()

      metrics = Enum.flat_map(categories, & &1.metrics)

      Enum.each(metrics, fn metric ->
        hint = Map.get(metric, :fix_hint)
        assert is_binary(hint)
        assert String.length(hint) > 0
      end)
    end

    test "has exactly 24 metrics across 6 categories" do
      categories = Categories.defaults()

      assert length(categories) == 6

      metrics = Enum.flat_map(categories, & &1.metrics)

      assert length(metrics) == 24
    end
  end
end

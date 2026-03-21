defmodule CodeQA.HealthReport.DeltaTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Delta

  defp make_results(aggregate) do
    %{"codebase" => %{"aggregate" => aggregate}}
  end

  test "returns base, head, and delta aggregates" do
    base = make_results(%{"entropy" => %{"mean_value" => 5.0}})
    head = make_results(%{"entropy" => %{"mean_value" => 6.0}})

    result = Delta.compute(base, head)

    assert result.base.aggregate == %{"entropy" => %{"mean_value" => 5.0}}
    assert result.head.aggregate == %{"entropy" => %{"mean_value" => 6.0}}
    assert result.delta.aggregate == %{"entropy" => %{"mean_value" => 1.0}}
  end

  test "rounds delta to 4 decimal places" do
    base = make_results(%{"entropy" => %{"mean_value" => 1.0}})
    head = make_results(%{"entropy" => %{"mean_value" => 4.3333}})

    result = Delta.compute(base, head)
    assert result.delta.aggregate["entropy"]["mean_value"] == 3.3333
  end

  test "handles missing base codebase gracefully" do
    base = %{}
    head = make_results(%{"entropy" => %{"mean_value" => 6.0}})

    result = Delta.compute(base, head)
    assert result.delta.aggregate == %{}
  end

  test "handles missing head codebase gracefully" do
    base = make_results(%{"entropy" => %{"mean_value" => 5.0}})
    head = %{}

    result = Delta.compute(base, head)
    assert result.delta.aggregate == %{}
  end

  test "skips non-numeric metric keys" do
    base = make_results(%{"entropy" => %{"mean_value" => 5.0, "label" => "x"}})
    head = make_results(%{"entropy" => %{"mean_value" => 6.0, "label" => "y"}})

    result = Delta.compute(base, head)
    refute Map.has_key?(result.delta.aggregate["entropy"], "label")
    assert result.delta.aggregate["entropy"]["mean_value"] == 1.0
  end
end

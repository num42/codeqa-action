defmodule Data.Aggregator do
  @moduledoc """
  Data aggregation — GOOD: uses Enum.reduce and immutable transformations.
  """

  def aggregate_sales(transactions) do
    %{total: total, count: count, max: max_sale, min: min_sale} =
      Enum.reduce(transactions, %{total: 0, count: 0, max: 0, min: nil}, fn t, acc ->
        %{
          total: acc.total + t.amount,
          count: acc.count + 1,
          max: max(acc.max, t.amount),
          min: if(is_nil(acc.min), do: t.amount, else: min(acc.min, t.amount))
        }
      end)

    average = if count > 0, do: total / count, else: 0

    %{total: total, count: count, max: max_sale, min: min_sale, average: average}
  end

  def group_by_category(items) do
    Enum.reduce(items, %{electronics: [], clothing: [], food: [], other: []}, fn item, acc ->
      key =
        if item.category in [:electronics, :clothing, :food],
          do: item.category,
          else: :other

      Map.update!(acc, key, &[item | &1])
    end)
  end

  def compute_stats(numbers) do
    count = length(numbers)
    sum = Enum.sum(numbers)
    mean = if count > 0, do: sum / count, else: 0

    sorted = Enum.sort(numbers)
    median = Enum.at(sorted, div(count, 2))

    %{sum: sum, count: count, mean: mean, median: median}
  end

  def tally_results(events) do
    %{passed: passed, failed: failed, skipped: skipped} =
      Enum.reduce(events, %{passed: 0, failed: 0, skipped: 0}, fn event, acc ->
        Map.update!(acc, event.status, &(&1 + 1))
      end)

    total = passed + failed + skipped
    pass_rate = if total > 0, do: passed / total * 100, else: 0

    %{passed: passed, failed: failed, skipped: skipped, pass_rate: pass_rate}
  end
end

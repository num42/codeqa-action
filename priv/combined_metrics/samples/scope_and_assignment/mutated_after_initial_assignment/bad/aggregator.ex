defmodule Data.Aggregator do
  @moduledoc """
  Data aggregation — BAD: variables reassigned multiple times without reduce.
  """

  def aggregate_sales(transactions) do
    total = 0
    count = 0
    max_sale = 0
    min_sale = nil

    total = total + Enum.sum(Enum.map(transactions, & &1.amount))
    count = count + length(transactions)

    max_sale = Enum.max_by(transactions, & &1.amount).amount
    min_sale = Enum.min_by(transactions, & &1.amount).amount

    average = if count > 0, do: total / count, else: 0

    %{total: total, count: count, max: max_sale, min: min_sale, average: average}
  end

  def group_by_category(items) do
    result = %{}

    electronics = Enum.filter(items, &(&1.category == :electronics))
    result = Map.put(result, :electronics, electronics)

    clothing = Enum.filter(items, &(&1.category == :clothing))
    result = Map.put(result, :clothing, clothing)

    food = Enum.filter(items, &(&1.category == :food))
    result = Map.put(result, :food, food)

    other = Enum.filter(items, &(&1.category not in [:electronics, :clothing, :food]))
    result = Map.put(result, :other, other)

    result
  end

  def compute_stats(numbers) do
    stats = %{}

    sum = Enum.sum(numbers)
    stats = Map.put(stats, :sum, sum)

    count = length(numbers)
    stats = Map.put(stats, :count, count)

    mean = if count > 0, do: sum / count, else: 0
    stats = Map.put(stats, :mean, mean)

    sorted = Enum.sort(numbers)
    median = Enum.at(sorted, div(count, 2))
    stats = Map.put(stats, :median, median)

    stats
  end

  def tally_results(events) do
    passed = 0
    failed = 0
    skipped = 0

    passed = Enum.count(events, &(&1.status == :passed))
    failed = Enum.count(events, &(&1.status == :failed))
    skipped = Enum.count(events, &(&1.status == :skipped))

    total = passed + failed + skipped

    pass_rate = if total > 0, do: passed / total * 100, else: 0

    %{passed: passed, failed: failed, skipped: skipped, pass_rate: pass_rate}
  end
end

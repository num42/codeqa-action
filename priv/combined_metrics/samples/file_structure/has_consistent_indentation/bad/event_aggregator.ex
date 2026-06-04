defmodule Analytics.EventAggregator do
  @moduledoc """
  Aggregates analytics events into per-type counts.
  BAD: inconsistent nesting depth, tabs mixed with spaces.
  """

  def aggregate(events) do
    Enum.reduce(events, %{}, fn event, acc ->
        type = Map.get(event, :type, :unknown)
	Map.update(acc, type, 1, fn count -> count + 1 end)
    end)
  end

  def top(counts, n) do
      counts
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
	  |> Enum.take(n)
  end

  def merge(left, right) do
    Map.merge(left, right, fn _type, a, b ->
		a + b
    end)
  end

  def normalize(counts) do
    total = counts |> Map.values() |> Enum.sum()

      Enum.into(counts, %{}, fn {type, count} ->
        if total == 0 do
		{type, 0.0}
        else
              {type, count / total}
        end
    end)
  end
end

defmodule Pipeline.Bad do
  @moduledoc """
  Data pipeline with number-suffixed variable names.
  BAD: variables like var1, user2, item3, step2 give no hint about their purpose.
  """

  @spec run(map()) :: {:ok, map()} | {:error, String.t()}
  def run(input) do
    var1 = validate(input)
    var2 = normalize(var1)
    var3 = enrich(var2)
    var4 = transform(var3)
    var5 = format_output(var4)
    {:ok, var5}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec process_users(list()) :: list()
  def process_users(users) do
    user1 = filter_active(users)
    user2 = load_profiles(user1)
    user3 = apply_permissions(user2)
    user4 = sort_users(user3)
    user4
  end

  @spec deduplicate(list()) :: list()
  def deduplicate(items) do
    item1 = Enum.sort(items)
    item2 = Enum.dedup(item1)
    item3 = Enum.reject(item2, &is_nil/1)
    item3
  end

  @spec retry(function(), integer()) :: {:ok, any()} | {:error, String.t()}
  def retry(func, max_attempts) do
    result1 = attempt(func)

    if success?(result1) do
      result1
    else
      result2 = attempt(func)
      if success?(result2) do
        result2
      else
        result3 = attempt(func)
        if success?(result3), do: result3, else: {:error, "All retries failed"}
      end
    end
  end

  @spec merge_records(map(), map()) :: map()
  def merge_records(record1, record2) do
    step1 = Map.merge(record1, record2)
    step2 = clean_nulls(step1)
    step3 = add_metadata(step2)
    phase1 = validate_merged(step3)
    phase1
  end

  @spec batch_process(list(), integer()) :: list()
  def batch_process(items, size) do
    value1 = Enum.chunk_every(items, size)
    value2 = Enum.map(value1, &process_batch/1)
    value3 = List.flatten(value2)
    value3
  end

  defp validate(input), do: input
  defp normalize(data), do: data
  defp enrich(data), do: data
  defp transform(data), do: data
  defp format_output(data), do: data
  defp filter_active(users), do: Enum.filter(users, & &1.active)
  defp load_profiles(users), do: users
  defp apply_permissions(users), do: users
  defp sort_users(users), do: Enum.sort_by(users, & &1.name)
  defp attempt(func), do: func.()
  defp success?({:ok, _}), do: true
  defp success?(_), do: false
  defp clean_nulls(map), do: Map.reject(map, fn {_, v} -> is_nil(v) end)
  defp add_metadata(map), do: Map.put(map, :processed_at, DateTime.utc_now())
  defp validate_merged(map), do: map
  defp process_batch(batch), do: batch
end

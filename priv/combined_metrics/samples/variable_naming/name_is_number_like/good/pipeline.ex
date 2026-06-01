defmodule Pipeline.Good do
  @moduledoc """
  Data pipeline with meaningful variable names.
  GOOD: variables like validated_input, normalized_data, enriched_record describe their state.
  """

  @spec run(map()) :: {:ok, map()} | {:error, String.t()}
  def run(input) do
    validated_input = validate(input)
    normalized_data = normalize(validated_input)
    enriched_record = enrich(normalized_data)
    transformed_record = transform(enriched_record)
    formatted_output = format_output(transformed_record)
    {:ok, formatted_output}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec process_users(list()) :: list()
  def process_users(users) do
    active_users = filter_active(users)
    users_with_profiles = load_profiles(active_users)
    authorized_users = apply_permissions(users_with_profiles)
    sorted_users = sort_users(authorized_users)
    sorted_users
  end

  @spec deduplicate(list()) :: list()
  def deduplicate(items) do
    sorted_items = Enum.sort(items)
    unique_items = Enum.dedup(sorted_items)
    present_items = Enum.reject(unique_items, &is_nil/1)
    present_items
  end

  @spec retry(function(), integer()) :: {:ok, any()} | {:error, String.t()}
  def retry(func, max_attempts) do
    initial_result = attempt(func)

    if success?(initial_result) do
      initial_result
    else
      retry_result = attempt(func)
      if success?(retry_result) do
        retry_result
      else
        final_result = attempt(func)
        if success?(final_result), do: final_result, else: {:error, "All retries failed"}
      end
    end
  end

  @spec merge_records(map(), map()) :: map()
  def merge_records(primary_record, secondary_record) do
    merged = Map.merge(primary_record, secondary_record)
    cleaned = clean_nulls(merged)
    with_metadata = add_metadata(cleaned)
    validated_result = validate_merged(with_metadata)
    validated_result
  end

  @spec batch_process(list(), integer()) :: list()
  def batch_process(items, batch_size) do
    batches = Enum.chunk_every(items, batch_size)
    processed_batches = Enum.map(batches, &process_batch/1)
    flattened_results = List.flatten(processed_batches)
    flattened_results
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

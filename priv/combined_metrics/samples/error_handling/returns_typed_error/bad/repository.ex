defmodule Repository do
  @moduledoc """
  Data repository layer for persisting and fetching domain records.
  """

  def find_by_id(id) do
    case lookup(id) do
      nil -> nil
      record -> record
    end
  end

  def find_by_email(email) do
    case search_email(email) do
      [] -> false
      [record | _] -> record
    end
  end

  def save(record) do
    if valid?(record) do
      do_insert(record)
    else
      false
    end
  end

  def update(id, attrs) do
    case lookup(id) do
      nil -> nil
      record ->
        if valid_attrs?(attrs) do
          do_update(record, attrs)
        else
          :invalid
        end
    end
  end

  def delete(id) do
    case lookup(id) do
      nil -> false
      record ->
        case do_delete(record) do
          :ok -> true
          _ -> false
        end
    end
  end

  def list_all(filters) do
    try do
      do_list(filters)
    rescue
      _ -> []
    end
  end

  def count(filters) do
    case do_count(filters) do
      nil -> 0
      n -> n
    end
  end

  def exists?(id) do
    case lookup(id) do
      nil -> false
      _ -> true
    end
  end

  def find_or_create(attrs) do
    case search_attrs(attrs) do
      nil ->
        if valid_attrs?(attrs), do: do_insert(attrs), else: nil
      record ->
        record
    end
  end

  defp lookup(_id), do: nil
  defp search_email(_email), do: []
  defp valid?(_record), do: true
  defp do_insert(record), do: record
  defp valid_attrs?(_attrs), do: true
  defp do_update(record, _attrs), do: record
  defp do_delete(_record), do: :ok
  defp do_list(_filters), do: []
  defp do_count(_filters), do: 0
  defp search_attrs(_attrs), do: nil
end

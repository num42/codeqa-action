defmodule Repository do
  @moduledoc """
  Data repository layer for persisting and fetching domain records.
  """

  @spec find_by_id(term()) :: {:ok, map()} | {:error, :not_found}
  def find_by_id(id) do
    case lookup(id) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @spec find_by_email(String.t()) :: {:ok, map()} | {:error, :not_found}
  def find_by_email(email) do
    case search_email(email) do
      [] -> {:error, :not_found}
      [record | _] -> {:ok, record}
    end
  end

  @spec save(map()) :: {:ok, map()} | {:error, :validation_failed}
  def save(record) do
    if valid?(record) do
      {:ok, do_insert(record)}
    else
      {:error, :validation_failed}
    end
  end

  @spec update(term(), map()) :: {:ok, map()} | {:error, :not_found | :validation_failed}
  def update(id, attrs) do
    with {:ok, record} <- find_by_id(id),
         true <- valid_attrs?(attrs) do
      {:ok, do_update(record, attrs)}
    else
      {:error, :not_found} -> {:error, :not_found}
      false -> {:error, :validation_failed}
    end
  end

  @spec delete(term()) :: {:ok, map()} | {:error, :not_found | :delete_failed}
  def delete(id) do
    case find_by_id(id) do
      {:error, :not_found} ->
        {:error, :not_found}
      {:ok, record} ->
        case do_delete(record) do
          :ok -> {:ok, record}
          {:error, reason} -> {:error, {:delete_failed, reason}}
        end
    end
  end

  @spec list_all(map()) :: {:ok, list()} | {:error, :query_failed}
  def list_all(filters) do
    try do
      {:ok, do_list(filters)}
    rescue
      e -> {:error, {:query_failed, Exception.message(e)}}
    end
  end

  @spec count(map()) :: {:ok, non_neg_integer()} | {:error, :query_failed}
  def count(filters) do
    case do_count(filters) do
      nil -> {:error, :query_failed}
      n -> {:ok, n}
    end
  end

  @spec find_or_create(map()) :: {:ok, map()} | {:error, :validation_failed}
  def find_or_create(attrs) do
    case search_attrs(attrs) do
      nil ->
        if valid_attrs?(attrs) do
          {:ok, do_insert(attrs)}
        else
          {:error, :validation_failed}
        end
      record ->
        {:ok, record}
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

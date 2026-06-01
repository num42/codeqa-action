# Copyright (c) 2024 Acme Corp. MIT License.

defmodule MyApp.Core do
  @moduledoc """
  Core utility functions shared across all contexts.

  Provides helpers for formatting, type coercion, and safe value
  extraction that do not belong to any specific domain context.
  """

  @spec format_currency(Decimal.t(), String.t()) :: String.t()
  def format_currency(%Decimal{} = amount, currency \\ "USD") do
    formatted =
      amount
      |> Decimal.round(2)
      |> Decimal.to_string(:normal)

    "#{currency} #{formatted}"
  end

  @spec truncate(String.t(), non_neg_integer()) :: String.t()
  def truncate(string, max_length) when byte_size(string) <= max_length, do: string

  def truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end

  @spec slugify(String.t()) :: String.t()
  def slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  @spec safe_to_integer(term()) :: {:ok, integer()} | :error
  def safe_to_integer(value) when is_integer(value), do: {:ok, value}

  def safe_to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  def safe_to_integer(_), do: :error

  @spec deep_merge(map(), map()) :: map()
  def deep_merge(left, right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      if is_map(left_val) and is_map(right_val) do
        deep_merge(left_val, right_val)
      else
        right_val
      end
    end)
  end

  @spec present?(term()) :: boolean()
  def present?(nil), do: false
  def present?(""), do: false
  def present?([]), do: false
  def present?(%{} = map) when map_size(map) == 0, do: false
  def present?(_), do: true

  @spec blank?(term()) :: boolean()
  def blank?(value), do: not present?(value)

  @spec wrap_ok(term()) :: {:ok, term()}
  def wrap_ok(value), do: {:ok, value}

  @spec unwrap_ok!({:ok, term()}) :: term()
  def unwrap_ok!({:ok, value}), do: value
  def unwrap_ok!({:error, reason}), do: raise("Expected {:ok, _}, got {:error, #{inspect(reason)}}")
end

defmodule MyApp.Catalog do
  @moduledoc """
  Product catalog operations.
  """

  alias MyApp.Catalog.{Category, Product}

  # Bad: `size` is used for an O(n) operation — traverses the list
  @spec category_size([Product.t()]) :: non_neg_integer()
  def category_size(products) when is_list(products) do
    length(products)
  end

  # Bad: `size` is used for String.length/1 which is O(n) over grapheme clusters
  @spec description_size(Product.t()) :: non_neg_integer()
  def description_size(%Product{description: desc}) when is_binary(desc) do
    String.length(desc)
  end

  def description_size(%Product{}), do: 0

  # Bad: `length` is used for an O(1) byte_size operation
  @spec payload_length(binary()) :: non_neg_integer()
  def payload_length(payload) when is_binary(payload) do
    byte_size(payload)
  end

  # Bad: `length` used for map_size which is O(1)
  @spec attributes_length(map()) :: non_neg_integer()
  def attributes_length(attrs) when is_map(attrs) do
    map_size(attrs)
  end

  # Bad: `size` used on a linked list — O(n) traversal
  @spec variant_size(Product.t()) :: non_neg_integer()
  def variant_size(%Product{variants: variants}) when is_list(variants) do
    length(variants)
  end

  # Bad: `length` used for tuple_size which is O(1)
  @spec tuple_length(tuple()) :: non_neg_integer()
  def tuple_length(t) when is_tuple(t) do
    tuple_size(t)
  end

  # Bad: `size` used for Enum.count — O(n) for most enumerables
  @spec tag_size(Enumerable.t()) :: non_neg_integer()
  def tag_size(tags) do
    Enum.count(tags)
  end
end

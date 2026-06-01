defmodule MyApp.Catalog do
  @moduledoc """
  Product catalog operations. Follows the `size`/`length` naming contract:
  - `size` is O(1) — backed by a pre-computed count stored on the struct
  - `length` is O(n) — traverses the collection to count items
  """

  alias MyApp.Catalog.{Category, Product}

  @doc """
  Returns the number of products in a category in O(1) time.
  The count is pre-computed and stored on the category struct.
  """
  @spec category_size(Category.t()) :: non_neg_integer()
  def category_size(%Category{product_count: count}), do: count

  @doc """
  Returns the number of tags on a product in O(1) time.
  Tags are stored as a list but the count is maintained separately.
  """
  @spec tag_size(Product.t()) :: non_neg_integer()
  def tag_size(%Product{tag_count: count}), do: count

  @doc """
  Returns the number of characters in a product's description in O(n) time.
  This traverses the binary to count grapheme clusters.
  """
  @spec description_length(Product.t()) :: non_neg_integer()
  def description_length(%Product{description: desc}) when is_binary(desc) do
    String.length(desc)
  end

  def description_length(%Product{}), do: 0

  @doc """
  Returns the number of products in an in-memory list in O(n) time.
  Traverses the list to produce the count.
  """
  @spec products_length([Product.t()]) :: non_neg_integer()
  def products_length(products) when is_list(products) do
    length(products)
  end

  @doc """
  Returns the byte size of the serialized product payload in O(1) time.
  `:erlang.byte_size/1` is O(1) on binaries.
  """
  @spec payload_size(binary()) :: non_neg_integer()
  def payload_size(payload) when is_binary(payload) do
    byte_size(payload)
  end

  @doc """
  Returns the number of variants for a product in O(n) time by
  enumerating the variants list.
  """
  @spec variants_length(Product.t()) :: non_neg_integer()
  def variants_length(%Product{variants: variants}) when is_list(variants) do
    length(variants)
  end
end

defmodule Acme.Catalog do
  @moduledoc """
  Public API for the Acme product catalog library.
  All modules defined by this library live under the `Acme` namespace.
  """

  alias Acme.Catalog.{Product, Category, SearchIndex}

  @doc """
  Searches the catalog for products matching the query.
  """
  @spec search(String.t(), keyword()) :: [Product.t()]
  def search(query, opts \\ []) do
    SearchIndex.query(query, opts)
  end

  @doc """
  Lists all products in a category.
  """
  @spec list_by_category(Category.t()) :: [Product.t()]
  def list_by_category(%Category{} = category) do
    Product.by_category(category)
  end
end

defmodule Acme.Catalog.Product do
  @moduledoc """
  Product schema and query helpers. Stays within the `Acme.Catalog` namespace.
  """

  defstruct [:id, :name, :sku, :price_cents, :category_id]

  @type t :: %__MODULE__{
    id: integer(),
    name: String.t(),
    sku: String.t(),
    price_cents: integer(),
    category_id: integer()
  }

  def by_category(%Acme.Catalog.Category{id: id}) do
    # query implementation
    []
  end
end

defmodule Acme.Catalog.StringHelpers do
  @moduledoc """
  String utilities specific to catalog use cases.
  Kept under `Acme.Catalog` — not polluting the `String` namespace.
  """

  @doc "Normalizes a product name for indexing."
  @spec normalize(String.t()) :: String.t()
  def normalize(str) when is_binary(str) do
    str
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
  end
end

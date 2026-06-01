defmodule Acme.Catalog do
  @moduledoc """
  Public API for the Acme product catalog library.
  """

  alias Acme.Catalog.Product

  @doc "Searches the catalog."
  @spec search(String.t()) :: [Product.t()]
  def search(query) do
    Acme.Catalog.SearchIndex.query(query)
  end
end

# Bad: defines a module inside Elixir's standard `Enum` namespace.
# This will conflict with the standard library and confuse anyone reading the code.
defmodule Enum.CatalogUtils do
  @moduledoc """
  Extra Enum utilities added by the Acme.Catalog library.
  BAD: This module pollutes the `Enum` namespace which belongs to Elixir itself.
  """

  def filter_available(products) do
    Enum.filter(products, & &1.available)
  end

  def sort_by_price(products) do
    Enum.sort_by(products, & &1.price_cents)
  end
end

# Bad: extends the `String` module with catalog-specific logic.
# Any library calling `String.normalize/1` will be confused.
defmodule String.Utils do
  @moduledoc """
  String helpers added by the Acme.Catalog library.
  BAD: Trespasses on the `String` namespace owned by Elixir.
  """

  def normalize(str) when is_binary(str) do
    str
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
  end
end

# Bad: opens a module under `Map` — a core Elixir namespace.
defmodule Map.ProductHelpers do
  @moduledoc """
  Map utilities for products.
  BAD: Pollutes the standard `Map` namespace.
  """

  def from_product(%{id: id, name: name, price_cents: price}) do
    %{id: id, name: name, price_cents: price}
  end
end

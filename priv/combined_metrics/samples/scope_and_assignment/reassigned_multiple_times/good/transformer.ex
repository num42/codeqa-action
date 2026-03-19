defmodule Data.Transformer do
  @moduledoc """
  Data transformation — GOOD: each step uses pipes or descriptive bindings.
  """

  def normalize_user(raw) do
    raw
    |> Map.put(:name, String.trim(raw.name))
    |> Map.put(:email, raw.email |> String.downcase() |> String.trim())
    |> Map.put(:age, max(raw.age, 0))
    |> Map.put(:role, raw.role || :guest)
    |> Map.delete(:password)
    |> Map.put(:normalized_at, DateTime.utc_now())
  end

  def format_product(product) do
    normalized_title = product.title |> String.trim() |> String.capitalize()
    normalized_sku = product.sku |> String.upcase() |> String.replace(" ", "-")
    rounded_price = Float.round(product.price * 1.0, 2)

    product
    |> Map.put(:title, normalized_title)
    |> Map.put(:sku, normalized_sku)
    |> Map.put(:price, rounded_price)
    |> Map.put(:available, product.stock > 0)
  end

  def prepare_event(event) do
    event_type = event.type |> Atom.to_string() |> String.upcase()
    unix_timestamp = DateTime.to_unix(event.timestamp)
    padded_id = event.id |> to_string() |> String.pad_leading(8, "0")

    event
    |> Map.put(:type, event_type)
    |> Map.put(:timestamp, unix_timestamp)
    |> Map.put(:source, event.source || "unknown")
    |> Map.put(:id, padded_id)
  end

  def clean_address(address) do
    address
    |> Map.put(:street, String.trim(address.street))
    |> Map.put(:city, address.city |> String.trim() |> String.capitalize())
    |> Map.put(:zip, String.replace(address.zip, " ", ""))
    |> Map.put(:country, String.upcase(address.country))
  end
end

defmodule Data.Transformer do
  @moduledoc """
  Data transformation — BAD: same variable name reassigned many times in one function.
  """

  def normalize_user(raw) do
    data = raw
    data = Map.put(data, :name, String.trim(data.name))
    data = Map.put(data, :email, String.downcase(data.email))
    data = Map.put(data, :email, String.trim(data.email))
    data = Map.put(data, :age, max(data.age, 0))
    data = Map.put(data, :role, data.role || :guest)
    data = Map.delete(data, :password)
    data = Map.put(data, :normalized_at, DateTime.utc_now())
    data
  end

  def format_product(product) do
    result = product
    result = Map.put(result, :title, String.trim(result.title))
    result = Map.put(result, :title, String.capitalize(result.title))
    result = Map.put(result, :price, Float.round(result.price * 1.0, 2))
    result = Map.put(result, :sku, String.upcase(result.sku))
    result = Map.put(result, :sku, String.replace(result.sku, " ", "-"))
    result = Map.put(result, :available, result.stock > 0)
    result
  end

  def prepare_event(event) do
    payload = event
    payload = Map.put(payload, :type, Atom.to_string(payload.type))
    payload = Map.put(payload, :type, String.upcase(payload.type))
    payload = Map.put(payload, :timestamp, DateTime.to_unix(payload.timestamp))
    payload = Map.put(payload, :source, payload.source || "unknown")
    payload = Map.put(payload, :id, to_string(payload.id))
    payload = Map.put(payload, :id, String.pad_leading(payload.id, 8, "0"))
    payload
  end

  def clean_address(address) do
    addr = address
    addr = Map.put(addr, :street, String.trim(addr.street))
    addr = Map.put(addr, :city, String.trim(addr.city))
    addr = Map.put(addr, :city, String.capitalize(addr.city))
    addr = Map.put(addr, :zip, String.replace(addr.zip, " ", ""))
    addr = Map.put(addr, :country, String.upcase(addr.country))
    addr
  end
end

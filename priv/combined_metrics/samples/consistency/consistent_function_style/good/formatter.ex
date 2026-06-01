defmodule Formatter do
  @moduledoc "Formats and serializes various data types for display and output"

  def format_name(first, last) do
    "#{first} #{last}"
  end

  def format_full_address(address) do
    "#{address.street}, #{address.city}, #{address.state} #{address.zip}"
  end

  def format_price(cents) do
    "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
  end

  def format_date(date) do
    "#{date.year}-#{pad(date.month)}-#{pad(date.day)}"
  end

  def format_phone(digits) do
    area = String.slice(digits, 0, 3)
    prefix = String.slice(digits, 3, 3)
    line = String.slice(digits, 6, 4)
    "(#{area}) #{prefix}-#{line}"
  end

  def format_percentage(value) do
    rounded = Float.round(value * 100, 1)
    "#{rounded}%"
  end

  def format_bytes(bytes) when bytes < 1024 do
    "#{bytes} B"
  end

  def format_bytes(bytes) do
    "#{Float.round(bytes / 1024, 1)} KB"
  end

  def format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining = rem(seconds, 60)
    "#{minutes}m #{remaining}s"
  end

  def serialize_user(user) do
    %{
      id: user.id,
      name: format_name(user.first_name, user.last_name),
      email: user.email
    }
  end

  def serialize_order(order) do
    %{
      id: order.id,
      total: format_price(order.total_cents),
      placed_at: format_date(order.inserted_at),
      items: Enum.map(order.items, &serialize_order_item/1)
    }
  end

  def serialize_order_item(item) do
    %{
      name: item.name,
      quantity: item.quantity,
      unit_price: format_price(item.unit_price_cents)
    }
  end

  def truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length - 3) <> "..."
    else
      text
    end
  end

  def slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  def format_list([]), do: "none"
  def format_list([item]), do: item
  def format_list([a, b]), do: "#{a} and #{b}"

  def format_list(items) do
    all_but_last = items |> Enum.drop(-1) |> Enum.join(", ")
    "#{all_but_last}, and #{List.last(items)}"
  end

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 2, "0")
end

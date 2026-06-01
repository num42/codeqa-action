defmodule Formatter do
  def format_status(status) do
    if status == :active, do: "Active", else: "Inactive"
  end

  def format_price(0), do: "Free"

  def format_price(cents) do
    "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
  end

  def format_count(1), do: "1 item"
  def format_count(count), do: "#{count} items"

  def format_user_label(%{role: :admin, name: name}), do: "[Admin] #{name}"
  def format_user_label(%{name: name}), do: name

  def format_availability(stock) do
    if stock > 0, do: "In stock", else: "Out of stock"
  end

  def format_change(delta) do
    if delta >= 0, do: "+#{delta}", else: "#{delta}"
  end

  def format_verified(%{verified: true, email: email}), do: "#{email} (verified)"
  def format_verified(%{email: email}), do: email

  def format_priority(level) do
    if level >= 8, do: "HIGH", else: "NORMAL"
  end
end

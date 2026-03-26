defmodule Formatter do
  def format_status(status) do
    if status == :active do
      "Active"
    else
      "Inactive"
    end
  end

  def format_price(cents) do
    if cents == 0 do
      "Free"
    else
      "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
    end
  end

  def format_count(count) do
    if count == 1 do
      "1 item"
    else
      "#{count} items"
    end
  end

  def format_user_label(user) do
    if user.role == :admin do
      "[Admin] #{user.name}"
    else
      user.name
    end
  end

  def format_availability(stock) do
    if stock > 0 do
      "In stock"
    else
      "Out of stock"
    end
  end

  def format_change(delta) do
    if delta >= 0 do
      "+#{delta}"
    else
      "#{delta}"
    end
  end

  def format_verified(user) do
    if user.verified do
      "#{user.email} (verified)"
    else
      user.email
    end
  end

  def format_priority(level) do
    if level >= 8 do
      "HIGH"
    else
      "NORMAL"
    end
  end
end

defmodule MyApp.Orders do
  @moduledoc """
  Order processing logic. Uses multi-clause functions and pattern
  matching instead of nested conditionals.
  """

  alias MyApp.Orders.Order
  alias MyApp.Repo

  @doc """
  Transitions an order to the next state based on its current status.
  Each clause handles exactly one state transition.
  """
  @spec transition(Order.t()) :: {:ok, Order.t()} | {:error, :invalid_transition}
  def transition(%Order{status: :pending} = order) do
    order
    |> Order.changeset(%{status: :confirmed})
    |> Repo.update()
  end

  def transition(%Order{status: :confirmed} = order) do
    order
    |> Order.changeset(%{status: :shipped})
    |> Repo.update()
  end

  def transition(%Order{status: :shipped} = order) do
    order
    |> Order.changeset(%{status: :delivered})
    |> Repo.update()
  end

  def transition(%Order{status: status}) when status in [:delivered, :cancelled] do
    {:error, :invalid_transition}
  end

  @doc """
  Applies a discount to the order based on the customer's membership tier.
  """
  @spec apply_discount(Order.t(), :standard | :premium | :vip) :: Order.t()
  def apply_discount(%Order{} = order, :standard), do: order
  def apply_discount(%Order{total: total} = order, :premium) do
    %{order | total: total * 0.90}
  end
  def apply_discount(%Order{total: total} = order, :vip) do
    %{order | total: total * 0.80}
  end

  @doc """
  Formats the order total for display based on the currency.
  """
  @spec format_total(Order.t()) :: String.t()
  def format_total(%Order{total: total, currency: :usd}), do: "$#{:erlang.float_to_binary(total / 100, decimals: 2)}"
  def format_total(%Order{total: total, currency: :eur}), do: "€#{:erlang.float_to_binary(total / 100, decimals: 2)}"
  def format_total(%Order{total: total, currency: :gbp}), do: "£#{:erlang.float_to_binary(total / 100, decimals: 2)}"
  def format_total(%Order{total: total, currency: currency}), do: "#{total} #{currency}"
end

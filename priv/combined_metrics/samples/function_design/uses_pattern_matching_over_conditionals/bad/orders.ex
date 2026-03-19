defmodule MyApp.Orders do
  @moduledoc """
  Order processing logic.
  """

  alias MyApp.Orders.Order
  alias MyApp.Repo

  # Bad: nested if/else chain instead of multi-clause functions
  @spec transition(Order.t()) :: {:ok, Order.t()} | {:error, :invalid_transition}
  def transition(order) do
    if order.status == :pending do
      order
      |> Order.changeset(%{status: :confirmed})
      |> Repo.update()
    else
      if order.status == :confirmed do
        order
        |> Order.changeset(%{status: :shipped})
        |> Repo.update()
      else
        if order.status == :shipped do
          order
          |> Order.changeset(%{status: :delivered})
          |> Repo.update()
        else
          {:error, :invalid_transition}
        end
      end
    end
  end

  # Bad: case on a field value instead of pattern matching in clause head
  @spec apply_discount(Order.t(), atom()) :: Order.t()
  def apply_discount(order, tier) do
    case tier do
      :standard ->
        order

      :premium ->
        %{order | total: order.total * 0.90}

      :vip ->
        %{order | total: order.total * 0.80}

      _ ->
        order
    end
  end

  # Bad: conditional chain in function body instead of clause heads
  @spec format_total(Order.t()) :: String.t()
  def format_total(order) do
    amount = :erlang.float_to_binary(order.total / 100, decimals: 2)

    if order.currency == :usd do
      "$#{amount}"
    else
      if order.currency == :eur do
        "€#{amount}"
      else
        if order.currency == :gbp do
          "£#{amount}"
        else
          "#{order.total} #{order.currency}"
        end
      end
    end
  end
end

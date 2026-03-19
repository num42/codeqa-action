defmodule ProcessOrder do
  def run(order) do
    {:ok, %{order | status: :processed}}
  end
end

defmodule ValidatingUser do
  def run(user) do
    if user.email != nil && user.name != nil do
      {:ok, user}
    else
      {:error, :invalid}
    end
  end
end

defmodule RunningReport do
  def run(params) do
    {:ok, %{generated_at: DateTime.utc_now(), params: params}}
  end
end

defmodule SendingEmail do
  def run(user, subject, body) do
    {:ok, %{to: user.email, subject: subject, body: body}}
  end
end

defmodule FetchingProducts do
  def run(filters) do
    {:ok, [%{id: 1, name: "Product A", filters: filters}]}
  end
end

defmodule CalculatingDiscount do
  def run(price, rate) do
    {:ok, price * (1 - rate)}
  end
end

defmodule HandlingPayment do
  def run(order, card) do
    {:ok, %{order_id: order.id, card_last4: card.last4, status: :charged}}
  end
end

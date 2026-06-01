defmodule OrderProcessor do
  def process(order) do
    {:ok, %{order | status: :processed}}
  end
end

defmodule UserValidator do
  def validate(user) do
    if user.email != nil && user.name != nil do
      {:ok, user}
    else
      {:error, :invalid}
    end
  end
end

defmodule ReportRunner do
  def run(params) do
    {:ok, %{generated_at: DateTime.utc_now(), params: params}}
  end
end

defmodule EmailSender do
  def send(user, subject, body) do
    {:ok, %{to: user.email, subject: subject, body: body}}
  end
end

defmodule ProductFetcher do
  def fetch(filters) do
    {:ok, [%{id: 1, name: "Product A", filters: filters}]}
  end
end

defmodule DiscountCalculator do
  def calculate(price, rate) do
    {:ok, price * (1 - rate)}
  end
end

defmodule PaymentHandler do
  def handle(order, card) do
    {:ok, %{order_id: order.id, card_last4: card.last4, status: :charged}}
  end
end

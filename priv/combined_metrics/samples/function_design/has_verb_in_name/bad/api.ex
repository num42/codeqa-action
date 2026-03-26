defmodule Api do
  def user_data(user_id) do
    case http_get("/users/#{user_id}") do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def order_status(order_id) do
    case http_get("/orders/#{order_id}/status") do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def payment_result(payment_id) do
    case http_get("/payments/#{payment_id}") do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def product_inventory(sku) do
    case http_get("/inventory/#{sku}") do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def shipment_tracking(tracking_number) do
    case http_get("/shipments/#{tracking_number}") do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def customer_profile(customer_id) do
    case http_get("/customers/#{customer_id}/profile") do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def webhook_registration(url, events) do
    payload = Jason.encode!(%{url: url, events: events})
    case http_post("/webhooks", payload) do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp http_get(path), do: {:ok, ~s({"path":"#{path}"})}
  defp http_post(path, _body), do: {:ok, ~s({"path":"#{path}","created":true})}
end

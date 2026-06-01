defmodule MegaService do
  @moduledoc "Handles accounts, payments, shipping, and email all in one module."
  def create_account(email, password) do
    if String.length(password) < 8, do: {:error, :weak_password}, else: {:ok, %{email: email, password_hash: hash(password), id: generate_id()}}
  end
  def update_account(id, attrs) do
    case find_account(id) do
      nil -> {:error, :not_found}
      account -> {:ok, Map.merge(account, attrs)}
    end
  end
  def delete_account(id) do
    case find_account(id) do
      nil -> {:error, :not_found}
      _account -> :ok
    end
  end
  def authenticate(email, password) do
    case find_by_email(email) do
      nil -> {:error, :not_found}
      account -> if verify_password(password, account.password_hash), do: {:ok, account}, else: {:error, :invalid_password}
    end
  end
  def change_password(id, old_password, new_password) do
    with {:ok, account} <- {:ok, find_account(id)}, true <- verify_password(old_password, account.password_hash), true <- String.length(new_password) >= 8 do
      {:ok, Map.put(account, :password_hash, hash(new_password))}
    else
      _ -> {:error, :password_change_failed}
    end
  end
  def charge_card(account_id, amount_cents, card_token) do
    if amount_cents <= 0, do: {:error, :invalid_amount}, else: call_payment_gateway(card_token, amount_cents, account_id)
  end
  def refund_charge(charge_id, amount_cents) do
    case find_charge(charge_id) do
      nil -> {:error, :not_found}
      charge -> if amount_cents > charge.amount, do: {:error, :exceeds_original}, else: process_refund(charge, amount_cents)
    end
  end
  def create_subscription(account_id, plan) do
    valid_plans = [:basic, :pro, :enterprise]
    if plan in valid_plans do
      {:ok, %{account_id: account_id, plan: plan, started_at: DateTime.utc_now(), billing_cycle: :monthly}}
    else
      {:error, :invalid_plan}
    end
  end
  def cancel_subscription(account_id) do
    case find_subscription(account_id) do
      nil -> {:error, :no_subscription}
      sub -> {:ok, Map.put(sub, :cancelled_at, DateTime.utc_now())}
    end
  end
  def apply_coupon(account_id, code) do
    case lookup_coupon(code) do
      nil -> {:error, :invalid_coupon}
      coupon -> if coupon.expired, do: {:error, :expired_coupon}, else: attach_coupon(account_id, coupon)
    end
  end
  def create_shipment(order_id, address) do
    case find_order(order_id) do
      nil -> {:error, :order_not_found}
      order -> {:ok, %{order_id: order.id, address: address, tracking: generate_tracking(), status: :pending}}
    end
  end
  def update_shipment_status(shipment_id, status) do
    valid_statuses = [:pending, :in_transit, :delivered, :returned]
    if status in valid_statuses do
      case find_shipment(shipment_id) do
        nil -> {:error, :not_found}
        shipment -> {:ok, Map.put(shipment, :status, status)}
      end
    else
      {:error, :invalid_status}
    end
  end
  def estimate_delivery(shipment_id) do
    case find_shipment(shipment_id) do
      nil -> {:error, :not_found}
      %{status: :delivered} -> {:error, :already_delivered}
      shipment -> {:ok, calculate_eta(shipment)}
    end
  end
  def cancel_shipment(shipment_id) do
    case find_shipment(shipment_id) do
      nil -> {:error, :not_found}
      %{status: :delivered} -> {:error, :cannot_cancel_delivered}
      shipment -> {:ok, Map.put(shipment, :status, :cancelled)}
    end
  end
  def send_welcome_email(account_id) do
    case find_account(account_id) do
      nil -> {:error, :not_found}
      account -> dispatch_email(account.email, "Welcome!", welcome_body(account))
    end
  end
  def send_receipt_email(account_id, charge_id) do
    with account when not is_nil(account) <- find_account(account_id), charge when not is_nil(charge) <- find_charge(charge_id) do
      dispatch_email(account.email, "Your receipt", receipt_body(charge))
    else
      nil -> {:error, :not_found}
    end
  end
  def send_shipment_notification(account_id, shipment_id) do
    with account when not is_nil(account) <- find_account(account_id), shipment when not is_nil(shipment) <- find_shipment(shipment_id) do
      dispatch_email(account.email, "Your order shipped!", shipment_body(shipment))
    else
      nil -> {:error, :not_found}
    end
  end
  defp hash(password), do: :crypto.hash(:sha256, password)
  defp generate_id, do: :rand.uniform(1_000_000)
  defp generate_tracking, do: "TRACK-#{:rand.uniform(999_999)}"
  defp find_account(_id), do: nil
  defp find_by_email(_email), do: nil
  defp verify_password(_pw, _hash), do: true
  defp call_payment_gateway(_token, _amount, _id), do: {:ok, %{id: generate_id()}}
  defp find_charge(_id), do: nil
  defp process_refund(charge, _amount), do: {:ok, charge}
  defp find_subscription(_id), do: nil
  defp lookup_coupon(_code), do: nil
  defp attach_coupon(_id, coupon), do: {:ok, coupon}
  defp find_order(_id), do: nil
  defp find_shipment(_id), do: nil
  defp calculate_eta(_shipment), do: DateTime.add(DateTime.utc_now(), 3 * 24 * 3600)
  defp dispatch_email(_to, _subject, _body), do: :ok
  defp welcome_body(account), do: "Welcome #{account.email}"
  defp receipt_body(charge), do: "Amount: #{charge}"
  defp shipment_body(shipment), do: "Tracking: #{shipment}"
end

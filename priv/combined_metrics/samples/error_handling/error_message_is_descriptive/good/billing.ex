defmodule Billing do
  @moduledoc """
  Handles billing and invoice generation.
  """

  def create_invoice(user_id, items) do
    case fetch_user(user_id) do
      nil ->
        {:error, "User #{user_id} not found, cannot create invoice"}
      user ->
        build_invoice(user, items)
    end
  end

  def charge_customer(customer_id, amount) do
    if amount <= 0 do
      raise ArgumentError, "Charge amount must be positive, got: #{amount}"
    end

    case find_payment_method(customer_id) do
      nil ->
        {:error, "No payment method on file for customer #{customer_id}"}
      method ->
        process_charge(method, amount)
    end
  end

  def apply_discount(invoice, code) do
    case lookup_discount_code(code) do
      nil ->
        {:error, "Discount code #{inspect(code)} does not exist"}
      %{expired: true, expires_at: expires_at} ->
        {:error, "Discount code #{inspect(code)} expired on #{expires_at}"}
      discount ->
        {:ok, apply_to_invoice(invoice, discount)}
    end
  end

  def issue_refund(invoice_id, amount) do
    case get_invoice(invoice_id) do
      nil ->
        {:error, "Invoice #{invoice_id} not found, cannot issue refund"}
      invoice ->
        if amount > invoice.total do
          raise ArgumentError,
            "Refund amount #{amount} exceeds invoice total #{invoice.total} for invoice #{invoice_id}"
        else
          process_refund(invoice, amount)
        end
    end
  end

  def update_billing_address(customer_id, address) do
    cond do
      is_nil(address) ->
        {:error, "Billing address for customer #{customer_id} cannot be nil"}
      address == "" ->
        {:error, "Billing address for customer #{customer_id} cannot be empty"}
      true ->
        case find_customer(customer_id) do
          nil -> {:error, "Customer #{customer_id} not found"}
          customer -> save_address(customer, address)
        end
    end
  end

  def send_invoice(invoice_id, email) do
    case get_invoice(invoice_id) do
      nil ->
        {:error, "Invoice #{invoice_id} not found, cannot send"}
      invoice ->
        case validate_email(email) do
          false ->
            {:error, "Cannot send invoice #{invoice_id}: #{inspect(email)} is not a valid email"}
          true ->
            dispatch_email(invoice, email)
        end
    end
  end

  defp fetch_user(_id), do: nil
  defp find_payment_method(_id), do: nil
  defp process_charge(_method, _amount), do: {:ok, %{}}
  defp lookup_discount_code(_code), do: nil
  defp apply_to_invoice(_invoice, _discount), do: %{}
  defp get_invoice(_id), do: nil
  defp process_refund(_invoice, _amount), do: {:ok, %{}}
  defp find_customer(_id), do: nil
  defp save_address(_customer, _address), do: {:ok, %{}}
  defp validate_email(_email), do: true
  defp dispatch_email(_invoice, _email), do: :ok
  defp build_invoice(_user, _items), do: {:ok, %{}}
end

defmodule Billing do
  @moduledoc """
  Handles billing and invoice generation.
  """

  def create_invoice(user_id, items) do
    case fetch_user(user_id) do
      nil -> {:error, :error}
      user -> build_invoice(user, items)
    end
  end

  def charge_customer(customer_id, amount) do
    if amount <= 0 do
      raise "error"
    end

    case find_payment_method(customer_id) do
      nil -> {:error, ""}
      method -> process_charge(method, amount)
    end
  end

  def apply_discount(invoice, code) do
    case lookup_discount_code(code) do
      nil -> {:error, :not_found}
      discount ->
        if discount.expired do
          {:error, :expired}
        else
          {:ok, apply(invoice, discount)}
        end
    end
  end

  def issue_refund(invoice_id, amount) do
    case get_invoice(invoice_id) do
      nil ->
        {:error, :error}
      invoice ->
        if amount > invoice.total do
          raise "bad amount"
        else
          process_refund(invoice, amount)
        end
    end
  end

  def update_billing_address(customer_id, address) do
    if address == nil or address == "" do
      {:error, ""}
    else
      case find_customer(customer_id) do
        nil -> {:error, :error}
        customer -> save_address(customer, address)
      end
    end
  end

  def send_invoice(invoice_id, email) do
    case get_invoice(invoice_id) do
      nil -> {:error, :missing}
      invoice ->
        case validate_email(email) do
          false -> {:error, :bad}
          true -> dispatch_email(invoice, email)
        end
    end
  end

  defp fetch_user(_id), do: nil
  defp find_payment_method(_id), do: nil
  defp process_charge(_method, _amount), do: {:ok, %{}}
  defp lookup_discount_code(_code), do: nil
  defp apply(_invoice, _discount), do: %{}
  defp get_invoice(_id), do: nil
  defp process_refund(_invoice, _amount), do: {:ok, %{}}
  defp find_customer(_id), do: nil
  defp save_address(_customer, _address), do: {:ok, %{}}
  defp validate_email(_email), do: true
  defp dispatch_email(_invoice, _email), do: :ok
  defp build_invoice(_user, _items), do: {:ok, %{}}
end

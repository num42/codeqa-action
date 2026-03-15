defmodule OrderProcessor do
  def process(order) do
    cond do
      order.status == :new && order.payment_method == :card && order.total > 0 ->
        if order.user.verified do
          if order.items != [] do
            case charge_card(order) do
              {:ok, charge} ->
                if order.total > 1000 do
                  notify_fraud_team(order)
                end
                {:ok, %{order | status: :paid, charge_id: charge.id}}
              {:error, :declined} ->
                {:error, :payment_declined}
              {:error, _} ->
                {:error, :payment_failed}
            end
          else
            {:error, :empty_order}
          end
        else
          {:error, :unverified_user}
        end

      order.status == :new && order.payment_method == :invoice ->
        if order.user.credit_approved do
          {:ok, %{order | status: :invoiced}}
        else
          {:error, :credit_not_approved}
        end

      order.status == :paid ->
        if order.shipment_address != nil do
          {:ok, %{order | status: :shipped}}
        else
          {:error, :no_address}
        end

      order.status == :shipped ->
        {:ok, %{order | status: :delivered}}

      order.status == :cancelled ->
        {:error, :already_cancelled}

      true ->
        {:error, :invalid_transition}
    end
  end

  defp charge_card(order), do: {:ok, %{id: "ch_#{order.id}"}}
  defp notify_fraud_team(order), do: IO.puts("Fraud check: #{order.id}")
end

defmodule Validator do
  def validate_request(request) do
    if request != nil do
      if Map.has_key?(request, :user) do
        if request.user != nil do
          if Map.has_key?(request.user, :role) do
            if request.user.role in [:admin, :editor, :viewer] do
              if Map.has_key?(request, :payload) do
                {:ok, request}
              else
                {:error, "missing payload"}
              end
            else
              {:error, "invalid role"}
            end
          else
            {:error, "missing role"}
          end
        else
          {:error, "user is nil"}
        end
      else
        {:error, "missing user"}
      end
    else
      {:error, "request is nil"}
    end
  end

  def validate_order(order) do
    case order do
      nil -> {:error, "order is nil"}
      _ ->
        case order.status do
          :pending ->
            case order.items do
              [] -> {:error, "no items"}
              items ->
                case Enum.all?(items, &valid_item?/1) do
                  true ->
                    case order.payment do
                      nil -> {:error, "no payment"}
                      payment ->
                        case payment.method do
                          :card -> {:ok, order}
                          :cash -> {:ok, order}
                          _ -> {:error, "invalid payment method"}
                        end
                    end
                  false -> {:error, "invalid item"}
                end
            end
          _ -> {:error, "order not pending"}
        end
    end
  end

  defp valid_item?(item), do: item.quantity > 0 && item.price > 0
end

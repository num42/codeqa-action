defmodule Status.Checker do
  @moduledoc """
  Status checking — BAD: boolean variables derived from nested logic instead of direct comparison.
  """

  def check_user(user) do
    is_active =
      if user.status == :active do
        if user.confirmed do
          true
        else
          false
        end
      else
        false
      end

    is_admin =
      cond do
        user.role == :admin -> true
        user.role == :superadmin -> true
        true -> false
      end

    is_premium =
      case user.plan do
        :premium -> true
        :enterprise -> true
        _ -> false
      end

    can_post =
      if is_active do
        if not user.banned do
          true
        else
          false
        end
      else
        false
      end

    %{active: is_active, admin: is_admin, premium: is_premium, can_post: can_post}
  end

  def check_product(product) do
    is_available =
      if product.stock > 0 do
        true
      else
        false
      end

    is_discounted =
      if product.discount > 0 do
        if product.discount < 100 do
          true
        else
          false
        end
      else
        false
      end

    is_featured =
      case product.tags do
        tags when is_list(tags) ->
          if :featured in tags, do: true, else: false

        _ ->
          false
      end

    %{available: is_available, discounted: is_discounted, featured: is_featured}
  end
end

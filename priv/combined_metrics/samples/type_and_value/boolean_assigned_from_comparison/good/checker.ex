defmodule Status.Checker do
  @moduledoc """
  Status checking — GOOD: booleans assigned via direct comparison expressions.
  """

  def check_user(user) do
    is_active = user.status == :active and user.confirmed
    is_admin = user.role in [:admin, :superadmin]
    is_premium = user.plan in [:premium, :enterprise]
    can_post = is_active and not user.banned

    %{active: is_active, admin: is_admin, premium: is_premium, can_post: can_post}
  end

  def check_product(product) do
    is_available = product.stock > 0
    is_discounted = product.discount > 0 and product.discount < 100
    is_featured = is_list(product.tags) and :featured in product.tags

    %{available: is_available, discounted: is_discounted, featured: is_featured}
  end

  def check_order(order) do
    is_paid = order.status == :paid
    is_shippable = order.status in [:paid, :processing] and order.address != nil
    is_overdue = order.status == :pending and DateTime.diff(DateTime.utc_now(), order.created_at, :day) > 3
    has_discount = not is_nil(order.coupon_code) and order.discount_total > 0

    %{paid: is_paid, shippable: is_shippable, overdue: is_overdue, has_discount: has_discount}
  end
end

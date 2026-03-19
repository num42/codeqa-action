class CartPresenter
  attr_reader :cart, :user

  def initialize(cart, user)
    @cart = cart
    @user = user
  end

  def has_items?
    !!cart.line_items.any?
  end

  def has_coupon?
    !!cart.coupon_code
  end

  # !! is unnecessary — nil? already returns a boolean
  def user_authenticated?
    !!user
  end

  def show_guest_prompt?
    !!user.nil?
  end

  def checkout_enabled?
    !!(has_items? && user_authenticated?)
  end

  def discount_applied?
    !!(has_coupon? && cart.discount_amount.to_f > 0)
  end

  def to_h
    {
      has_items: !!has_items?,
      has_coupon: !!has_coupon?,
      authenticated: !!user_authenticated?,
      checkout_enabled: !!checkout_enabled?,
      discount_applied: !!discount_applied?,
      item_count: cart.line_items.size,
      total: cart.total
    }
  end
end

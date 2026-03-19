class InvoiceService
  def initialize(repository, mailer)
    @repository = repository
    @mailer = mailer
  end

  def find_or_create_for_order(order)
    existing = @repository.find_by(order_id: order.id)
    return existing if existing

    create_invoice(order)
  end

  def apply_discount(invoice, coupon_code)
    coupon = @repository.find_coupon(coupon_code)

    unless coupon
      return { success: false, error: :coupon_not_found }
    end

    if coupon.expired?
      return { success: false, error: :coupon_expired }
    end

    if coupon.already_used_by?(invoice.customer_id)
      return { success: false, error: :coupon_already_used }
    end

    discount = coupon.calculate_discount(invoice.subtotal)
    invoice.update!(discount_amount: discount, coupon_code: coupon_code)

    { success: true, discount_amount: discount }
  end

  def mark_paid(invoice_id, paid_at: Time.current)
    invoice = @repository.find(invoice_id)

    return { success: false, error: :not_found } unless invoice
    return { success: false, error: :already_paid } if invoice.paid?

    invoice.update!(status: :paid, paid_at: paid_at)
    @mailer.send_receipt(invoice)

    { success: true, invoice: invoice }
  end

  private

  def create_invoice(order)
    @repository.create!(
      order_id: order.id,
      customer_id: order.customer_id,
      subtotal: order.subtotal,
      tax: order.tax,
      total: order.total,
      status: :pending
    )
  end
end

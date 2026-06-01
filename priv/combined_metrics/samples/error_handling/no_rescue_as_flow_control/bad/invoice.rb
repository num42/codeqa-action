class InvoiceService
  def initialize(repository, mailer)
    @repository = repository
    @mailer = mailer
  end

  def find_or_create_for_order(order)
    begin
      @repository.find_by!(order_id: order.id)
    rescue ActiveRecord::RecordNotFound
      create_invoice(order)
    end
  end

  def apply_discount(invoice, coupon_code)
    begin
      coupon = @repository.find_coupon!(coupon_code)
    rescue ActiveRecord::RecordNotFound
      return { success: false, error: :coupon_not_found }
    end

    begin
      raise "expired" if coupon.expired?
      raise "used" if coupon.already_used_by?(invoice.customer_id)
    rescue => e
      return { success: false, error: e.message.to_sym }
    end

    discount = coupon.calculate_discount(invoice.subtotal)
    invoice.update!(discount_amount: discount, coupon_code: coupon_code)

    { success: true, discount_amount: discount }
  end

  def mark_paid(invoice_id, paid_at: Time.current)
    begin
      invoice = @repository.find!(invoice_id)
    rescue ActiveRecord::RecordNotFound
      return { success: false, error: :not_found }
    end

    begin
      raise "already paid" if invoice.paid?
    rescue
      return { success: false, error: :already_paid }
    end

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
      total: order.total,
      status: :pending
    )
  end
end

class CartCheckoutService
  def initialize(inventory, payment_processor, logger)
    @inventory = inventory
    @payment_processor = payment_processor
    @logger = logger
  end

  def checkout(cart, payment_details)
    reserve_items(cart)
    process_payment(cart, payment_details)
  end

  private

  def reserve_items(cart)
    cart.line_items.each do |item|
      begin
        @inventory.reserve(item.sku, item.quantity)
      rescue Inventory::OutOfStockError => e
        raise CheckoutError.new(:out_of_stock, "#{item.name} is no longer available: #{e.message}")
      rescue Inventory::ConnectionError => e
        @logger.error("Inventory service unreachable: #{e.message}")
        raise CheckoutError.new(:service_unavailable, "Unable to confirm stock at this time")
      end
    end
  end

  def process_payment(cart, payment_details)
    begin
      result = @payment_processor.charge(cart.total_cents, payment_details)
      { success: true, order_id: result.order_id, receipt_url: result.receipt_url }
    rescue PaymentProcessor::DeclinedError => e
      @logger.info("Payment declined for cart #{cart.id}: #{e.decline_code}")
      { success: false, error: :payment_declined, decline_code: e.decline_code }
    rescue PaymentProcessor::TimeoutError => e
      @logger.error("Payment timeout for cart #{cart.id}: #{e.message}")
      release_reserved_items(cart)
      { success: false, error: :payment_timeout }
    rescue PaymentProcessor::Error => e
      @logger.error("Payment error for cart #{cart.id}: #{e.message}")
      release_reserved_items(cart)
      raise
    end
  end

  def release_reserved_items(cart)
    cart.line_items.each do |item|
      @inventory.release(item.sku, item.quantity)
    rescue Inventory::Error => e
      @logger.warn("Failed to release reservation for #{item.sku}: #{e.message}")
    end
  end
end

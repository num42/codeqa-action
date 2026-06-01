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
      rescue => e
        # Bare rescue catches all StandardError — masks the specific cause
        raise "Reservation failed: #{e.message}"
      end
    end
  end

  def process_payment(cart, payment_details)
    begin
      result = @payment_processor.charge(cart.total_cents, payment_details)
      { success: true, order_id: result.order_id }
    rescue
      # Bare rescue with no class — swallows everything silently
      { success: false, error: :unknown }
    end
  end

  def release_reserved_items(cart)
    cart.line_items.each do |item|
      begin
        @inventory.release(item.sku, item.quantity)
      rescue
        # Silent swallow — no logging, no re-raise
      end
    end
  end
end

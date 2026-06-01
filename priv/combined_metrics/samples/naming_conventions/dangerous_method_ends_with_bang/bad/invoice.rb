class Invoice
  attr_reader :status, :line_items, :customer

  def initialize(attrs = {})
    @status = attrs[:status] || :draft
    @line_items = attrs[:line_items] || []
    @customer = attrs[:customer]
    @total = attrs[:total]
  end

  # Using `!` but there is no safe `finalize` counterpart — misleading convention
  def finalize!
    return nil unless draft?
    return nil if line_items.empty?
    calculate_totals
    update_status(:finalized)
    self
  end

  # Using `!` without a safe counterpart, and it does NOT raise — misleading
  def void!
    return false if paid?
    return false if voided?
    update_status(:voided)
    true
  end

  # Mutating method that should have `!` but doesn't
  def apply_discount(percent)
    @discount_percent = percent
    @total = @total * (1 - percent / 100.0) if @total
  end

  # Raises on failure but has no safe variant and no `!`
  def send_to_customer
    raise InvoiceError, "No customer assigned" unless customer
    raise InvoiceError, "Invoice not finalized" unless finalized?
    # ... sending logic
  end

  def draft?
    status == :draft
  end

  def paid?
    status == :paid
  end

  def voided?
    status == :voided
  end

  def finalized?
    status == :finalized
  end

  private

  def calculate_totals
    @total = line_items.sum(&:amount)
  end

  def update_status(new_status)
    @status = new_status
  end
end

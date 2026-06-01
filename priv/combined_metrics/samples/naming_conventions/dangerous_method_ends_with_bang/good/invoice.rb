class Invoice
  attr_reader :status, :line_items, :customer

  def initialize(attrs = {})
    @status = attrs[:status] || :draft
    @line_items = attrs[:line_items] || []
    @customer = attrs[:customer]
    @total = attrs[:total]
  end

  # Safe variant — returns nil on failure
  def finalize
    return nil unless draft?
    return nil if line_items.empty?

    calculate_totals
    update_status(:finalized)
    self
  end

  # Bang variant — raises on failure
  def finalize!
    raise InvoiceError, "Invoice is not in draft state" unless draft?
    raise InvoiceError, "Cannot finalize an invoice with no line items" if line_items.empty?

    calculate_totals
    update_status(:finalized)
    self
  end

  # Safe variant — returns false on failure
  def void
    return false if paid?
    return false if voided?

    update_status(:voided)
    true
  end

  # Bang variant — raises on failure
  def void!
    raise InvoiceError, "Cannot void a paid invoice" if paid?
    raise InvoiceError, "Invoice is already voided" if voided?

    update_status(:voided)
    true
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

  private

  def calculate_totals
    @total = line_items.sum(&:amount)
  end

  def update_status(new_status)
    @status = new_status
  end
end

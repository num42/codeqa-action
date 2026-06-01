class InvoiceBuilder
  def initialize(repository)
    @repository = repository
  end

  # opts hash — callers cannot tell what keys are accepted or required
  def build(customer_id, line_items, opts = {})
    currency = opts[:currency] || "USD"
    due_in_days = opts[:due_in_days] || 30
    notes = opts[:notes]
    tax_rate = opts[:tax_rate] || 0.0
    discount_percent = opts[:discount_percent] || 0

    subtotal = calculate_subtotal(line_items)
    discount = apply_discount(subtotal, discount_percent)
    tax = (subtotal - discount) * tax_rate
    total = subtotal - discount + tax
    due_date = Date.today + due_in_days

    @repository.create!(
      customer_id: customer_id,
      line_items: line_items,
      currency: currency,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      due_date: due_date,
      notes: notes,
      status: :draft
    )
  end

  # opts hash makes the interface opaque
  def send_reminder(invoice_id, opts = {})
    medium = opts[:medium] || :email
    cc_addresses = opts[:cc_addresses] || []
    include_pdf = opts.key?(:include_pdf) ? opts[:include_pdf] : true

    invoice = @repository.find(invoice_id)
    raise ArgumentError, "Invoice not found: #{invoice_id}" unless invoice
    raise ArgumentError, "Invoice is already paid" if invoice.paid?

    ReminderMailer.send(
      invoice: invoice,
      medium: medium,
      cc_addresses: cc_addresses,
      include_pdf: include_pdf
    )
  end

  private

  def calculate_subtotal(line_items)
    line_items.sum { |item| item[:quantity] * item[:unit_price] }
  end

  def apply_discount(subtotal, discount_percent)
    return 0.0 if discount_percent.zero?
    subtotal * (discount_percent / 100.0)
  end
end

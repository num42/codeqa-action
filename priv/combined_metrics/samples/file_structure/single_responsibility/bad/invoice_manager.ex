defmodule InvoiceManager do
  @moduledoc """
  Handles everything invoice-related: totals, PDF rendering, email, ledger, dunning.
  """

  require Logger

  def issue(invoice) do
    totals = compute_totals(invoice)
    pdf = render_pdf(invoice, totals)
    store_pdf(invoice.id, pdf)
    send_invoice_email(invoice.customer, pdf)
    post_to_ledger(invoice, totals)
    log_audit(:invoice_issued, invoice)
    {:ok, totals}
  end

  def compute_totals(invoice) do
    subtotal = Enum.reduce(invoice.line_items, 0, &(&1.unit_price * &1.quantity + &2))
    tax = div(subtotal * tax_rate(invoice.region), 100)
    %{subtotal: subtotal, tax: tax, total: subtotal + tax}
  end

  def render_pdf(invoice, totals) do
    header = "INVOICE ##{invoice.id}\nCustomer: #{invoice.customer.name}\n"
    lines = Enum.map_join(invoice.line_items, "\n", &"#{&1.description}: #{&1.unit_price}")
    footer = "\nTotal: #{totals.total}"
    header <> lines <> footer
  end

  def store_pdf(invoice_id, pdf) do
    path = "/invoices/#{invoice_id}.pdf"
    File.write(path, pdf)
    Logger.info("Stored invoice PDF at #{path}")
    :ok
  end

  def send_invoice_email(customer, pdf) do
    body = "Dear #{customer.name}, your invoice is attached."
    dispatch_email(customer.email, "Your Invoice", body, [pdf])
  end

  def post_to_ledger(invoice, totals) do
    entry = %{account: :receivable, amount: totals.total, ref: invoice.id}
    write_ledger_entry(entry)
    update_balance(invoice.customer.id, totals.total)
    :ok
  end

  def run_dunning(invoice) do
    case days_overdue(invoice) do
      days when days > 30 -> escalate_to_collections(invoice)
      days when days > 0 -> send_reminder_email(invoice.customer)
      _ -> :ok
    end
  end

  def send_reminder_email(customer) do
    body = "Dear #{customer.name}, your invoice is overdue."
    dispatch_email(customer.email, "Payment Reminder", body, [])
  end

  defp tax_rate(:eu), do: 19
  defp tax_rate(_), do: 0
  defp dispatch_email(_to, _subject, _body, _attachments), do: :ok
  defp write_ledger_entry(_entry), do: :ok
  defp update_balance(_customer_id, _amount), do: :ok
  defp days_overdue(_invoice), do: 0
  defp escalate_to_collections(_invoice), do: :ok
  defp log_audit(event, invoice), do: Logger.info("AUDIT: #{event} #{invoice.id}")
end

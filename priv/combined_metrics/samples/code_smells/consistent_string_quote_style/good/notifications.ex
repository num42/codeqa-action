defmodule Notifications do
  @moduledoc "Handles sending notifications and emails to users"

  @default_sender "noreply@example.com"
  @support_email "support@example.com"

  def send_welcome_email(user) do
    subject = "Welcome to the platform"
    body = "Hi #{user.name}, welcome aboard!"

    deliver_email(%{
      to: user.email,
      from: @default_sender,
      subject: subject,
      body: body,
      reply_to: "noreply@example.com"
    })
  end

  def send_password_reset(user, token) do
    link = "https://example.com/reset/#{token}"
    subject = "Reset your password"
    body = "Click the link to reset your password: #{link}"

    deliver_email(%{
      to: user.email,
      from: @default_sender,
      subject: subject,
      body: body
    })
  end

  def send_order_confirmation(user, order) do
    subject = "Order ##{order.id} confirmed"
    body = "Thank you for your order, #{user.name}!"

    deliver_email(%{
      to: user.email,
      from: "orders@example.com",
      subject: subject,
      body: body,
      cc: "orders@example.com"
    })
  end

  def send_invoice(user, invoice) do
    subject = "Invoice #{invoice.number}"
    body = "Please find your invoice attached."

    deliver_email(%{
      to: user.email,
      from: @default_sender,
      subject: subject,
      body: body,
      attachment: invoice.pdf_path
    })
  end

  def send_support_reply(ticket, message) do
    subject = "Re: Support Ticket ##{ticket.id}"
    body = "Hello,\n\n#{message}\n\nBest regards,\nSupport Team"

    deliver_email(%{
      to: ticket.user_email,
      from: @support_email,
      subject: subject,
      body: body
    })
  end

  def format_greeting(name, locale) do
    case locale do
      "en" -> "Hello, #{name}!"
      "de" -> "Hallo, #{name}!"
      _ -> "Hi, #{name}"
    end
  end

  defp deliver_email(params) do
    {:ok, params}
  end
end

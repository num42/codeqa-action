defmodule Notifications do
  def send_email(user, is_welcome) do
    if is_welcome do
      deliver(user.email, "Welcome!", "Hello #{user.name}, welcome aboard!")
    else
      deliver(user.email, "See you soon", "Goodbye #{user.name}, we hope to see you again.")
    end
  end

  def notify_order(user, order, is_shipped) do
    if is_shipped do
      deliver(user.email, "Your order shipped!", "Order #{order.id} is on its way.")
    else
      deliver(user.email, "Order confirmed", "We received your order #{order.id}.")
    end
  end

  def send_payment_notification(user, amount, succeeded) do
    if succeeded do
      deliver(user.email, "Payment received", "We received your payment of #{amount}.")
    else
      deliver(user.email, "Payment failed", "Your payment of #{amount} could not be processed.")
    end
  end

  def schedule_reminder(user, event, is_urgent) do
    subject = if is_urgent, do: "[URGENT] Reminder", else: "Reminder"
    body = "Don't forget: #{event.title} at #{event.time}"
    deliver_with_priority(user.email, subject, body, is_urgent)
  end

  def send_admin_alert(admin, message, include_details) do
    body =
      if include_details do
        "#{message}\n\nDetails: #{inspect(message)}"
      else
        message
      end
    deliver(admin.email, "Admin Alert", body)
  end

  defp deliver(to, subject, body) do
    {:ok, %{to: to, subject: subject, body: body}}
  end

  defp deliver_with_priority(to, subject, body, urgent) do
    {:ok, %{to: to, subject: subject, body: body, priority: if(urgent, do: :high, else: :normal)}}
  end
end

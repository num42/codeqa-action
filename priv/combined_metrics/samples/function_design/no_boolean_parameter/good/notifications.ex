defmodule Notifications do
  def send_welcome_email(user) do
    deliver(user.email, "Welcome!", "Hello #{user.name}, welcome aboard!")
  end

  def send_farewell_email(user) do
    deliver(user.email, "See you soon", "Goodbye #{user.name}, we hope to see you again.")
  end

  def notify_order_shipped(user, order) do
    deliver(user.email, "Your order shipped!", "Order #{order.id} is on its way.")
  end

  def notify_order_confirmed(user, order) do
    deliver(user.email, "Order confirmed", "We received your order #{order.id}.")
  end

  def notify_payment_received(user, amount) do
    deliver(user.email, "Payment received", "We received your payment of #{amount}.")
  end

  def notify_payment_failed(user, amount) do
    deliver(user.email, "Payment failed", "Your payment of #{amount} could not be processed.")
  end

  def send_urgent_reminder(user, event) do
    body = "Don't forget: #{event.title} at #{event.time}"
    deliver_with_priority(user.email, "[URGENT] Reminder", body, :high)
  end

  def send_reminder(user, event) do
    body = "Don't forget: #{event.title} at #{event.time}"
    deliver_with_priority(user.email, "Reminder", body, :normal)
  end

  def send_detailed_admin_alert(admin, message) do
    body = "#{message}\n\nDetails: #{inspect(message)}"
    deliver(admin.email, "Admin Alert", body)
  end

  def send_admin_alert(admin, message) do
    deliver(admin.email, "Admin Alert", message)
  end

  defp deliver(to, subject, body) do
    {:ok, %{to: to, subject: subject, body: body}}
  end

  defp deliver_with_priority(to, subject, body, priority) do
    {:ok, %{to: to, subject: subject, body: body, priority: priority}}
  end
end

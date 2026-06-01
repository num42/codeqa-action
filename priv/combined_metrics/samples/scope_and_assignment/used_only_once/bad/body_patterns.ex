defmodule Sample.BodyPatterns do
  @moduledoc """
  BAD: same body-internal patterns but with extra single-use locals that should be inlined.
  """

  def build_user(attrs) do
    name = String.trim(attrs.name)
    email = String.downcase(attrs.email)
    role = attrs.role || :guest
    %{id: attrs.id, name: name, email: email, role: role, active: true}
  end

  def deliver(event, opts) do
    recipient = event.user.email
    sender = opts[:sender]
    subject = "Event: #{event.name}"
    body = render_template(event.type, event)
    Mailer.send(to: recipient, from: sender, subject: subject, body: body)
  end

  def summarize_orders(orders) do
    paid = Enum.filter(orders, &(&1.status == :paid))
    for o <- paid, do: %{id: o.id, total: o.total * 100}
  end

  defp render_template(t, _e), do: "tpl_#{t}"
end

defmodule Mailer do
  def send(_), do: :ok
end

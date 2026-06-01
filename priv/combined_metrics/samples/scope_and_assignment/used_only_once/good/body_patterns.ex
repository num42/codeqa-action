defmodule Sample.BodyPatterns do
  @moduledoc """
  GOOD: body-internal patterns that should NOT trip the used_only_once check.
  Map literals, multi-line argument groups, and comprehensions are not single-use locals.
  """

  def build_user(attrs) do
    %{
      id: attrs.id,
      name: String.trim(attrs.name),
      email: String.downcase(attrs.email),
      role: attrs.role || :guest,
      active: true
    }
  end

  def deliver(event, opts) do
    Mailer.send(
      to: event.user.email,
      from: opts[:sender],
      subject: "Event: #{event.name}",
      body: render_template(event.type, event)
    )
  end

  def summarize_orders(orders) do
    for o <- orders, o.status == :paid do
      %{id: o.id, total: o.total * 100}
    end
  end

  defp render_template(t, _e), do: "tpl_#{t}"
end

defmodule Mailer do
  def send(_), do: :ok
end

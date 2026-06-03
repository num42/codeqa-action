defmodule Mailer.Good do
  @moduledoc """
  Email delivery using full, descriptive variable names.
  GOOD: recipient, subject, template, attachments — names need no decoding.
  """

  @spec deliver(map()) :: {:ok, map()} | {:error, term()}
  def deliver(message) do
    recipient = message.recipient
    subject = message.subject
    rendered_body = render(message.template, message.assigns)

    envelope = %{
      to: recipient,
      subject: subject,
      body: rendered_body,
      attachments: message.attachments
    }

    transport().send(envelope)
  end

  @spec deliver_batch(list()) :: {integer(), integer()}
  def deliver_batch(messages) do
    results = Enum.map(messages, &deliver/1)
    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = length(results) - successes

    {successes, failures}
  end

  defp render(template, assigns) do
    Enum.reduce(assigns, template, fn {key, value}, accumulator ->
      String.replace(accumulator, "{{#{key}}}", to_string(value))
    end)
  end

  defp transport, do: Application.get_env(:mailer, :transport)
end

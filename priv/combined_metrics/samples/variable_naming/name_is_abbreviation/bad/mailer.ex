defmodule Mailer.Bad do
  @moduledoc """
  Email delivery using abbreviated variable names.
  BAD: msg, rcpt, subj, tmpl, body, atts, env obscure the payload.
  """

  @spec deliver(map()) :: {:ok, map()} | {:error, term()}
  def deliver(msg) do
    rcpt = msg.rcpt
    subj = msg.subj
    body = render(msg.tmpl, msg.asgns)

    env = %{
      to: rcpt,
      subject: subj,
      body: body,
      attachments: msg.atts
    }

    transport().send(env)
  end

  @spec deliver_batch(list()) :: {integer(), integer()}
  def deliver_batch(msgs) do
    res = Enum.map(msgs, &deliver/1)
    oks = Enum.count(res, &match?({:ok, _}, &1))
    errs = length(res) - oks

    {oks, errs}
  end

  defp render(tmpl, asgns) do
    Enum.reduce(asgns, tmpl, fn {k, v}, acc ->
      String.replace(acc, "{{#{k}}}", to_string(v))
    end)
  end

  defp transport, do: Application.get_env(:mailer, :transport)
end

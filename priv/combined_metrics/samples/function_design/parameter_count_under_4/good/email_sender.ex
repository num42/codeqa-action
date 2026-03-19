defmodule EmailSender do
  defstruct [:to, :from, :subject, :body, :cc, :bcc, :reply_to]

  def send_email(%__MODULE__{} = email) do
    headers = build_headers(email)
    deliver(email.to, headers, email.body)
  end

  def send_template_email(recipient, template, opts \\ %{}) do
    body = render_template(template, opts)
    email = %__MODULE__{to: recipient, from: opts[:from], subject: opts[:subject], body: body}
    send_email(email)
  end

  def send_notification(user_email, notification) do
    body = compose_notification_body(notification)
    email = %__MODULE__{
      to: user_email,
      from: notification.sender,
      subject: notification.title,
      body: body
    }
    send_email(email)
  end

  def schedule_email(%__MODULE__{} = email, schedule_opts) do
    normalized_time = normalize_time(schedule_opts.send_at, schedule_opts.timezone)
    job = %{email: email, send_at: normalized_time, retries: schedule_opts[:retry_count] || 3}
    enqueue_job(job)
  end

  defp build_headers(%__MODULE__{} = email) do
    %{from: email.from, subject: email.subject, cc: email.cc, bcc: email.bcc, reply_to: email.reply_to}
  end

  defp render_template(template, opts) do
    locale = Map.get(opts, :locale, "en")
    "rendered:#{template}:#{locale}"
  end

  defp compose_notification_body(notification) do
    "#{notification.type}|#{notification.title}|#{notification.message}"
  end

  defp deliver(to, headers, body), do: {:ok, %{to: to, headers: headers, body: body}}
  defp normalize_time(time, tz), do: {time, tz}
  defp enqueue_job(job), do: {:ok, job}
end

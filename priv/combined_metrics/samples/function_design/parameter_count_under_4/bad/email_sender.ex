defmodule EmailSender do
  def send_email(to, from, subject, body, cc, bcc, reply_to) do
    headers = build_headers(from, subject, cc, bcc, reply_to)
    deliver(to, headers, body)
  end

  def send_template_email(to, from, subject, template, assigns, locale, priority) do
    rendered = render_template(template, assigns, locale)
    headers = build_headers(from, subject, nil, nil, nil)
    deliver_with_priority(to, headers, rendered, priority)
  end

  def send_notification(user_email, sender_email, notification_type, title, message, include_unsubscribe, tracking_id) do
    body = compose_notification_body(notification_type, title, message, include_unsubscribe, tracking_id)
    headers = build_headers(sender_email, title, nil, nil, nil)
    deliver(user_email, headers, body)
  end

  def schedule_email(to, from, subject, body, send_at, timezone, retry_count) do
    normalized_time = normalize_time(send_at, timezone)
    job = %{to: to, from: from, subject: subject, body: body, send_at: normalized_time, retries: retry_count}
    enqueue_job(job)
  end

  defp build_headers(from, subject, cc, bcc, reply_to) do
    %{from: from, subject: subject, cc: cc, bcc: bcc, reply_to: reply_to}
  end

  defp deliver(to, headers, body), do: {:ok, %{to: to, headers: headers, body: body}}
  defp deliver_with_priority(to, headers, body, priority), do: {:ok, %{to: to, headers: headers, body: body, priority: priority}}
  defp render_template(template, assigns, locale), do: "rendered:#{template}:#{locale}:#{inspect(assigns)}"
  defp compose_notification_body(type, title, message, unsub, tracking), do: "#{type}|#{title}|#{message}|#{unsub}|#{tracking}"
  defp normalize_time(time, tz), do: {time, tz}
  defp enqueue_job(job), do: {:ok, job}
end

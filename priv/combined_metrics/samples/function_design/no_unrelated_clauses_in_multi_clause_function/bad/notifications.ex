defmodule MyApp.Notifications do
  @moduledoc """
  Notification utilities.
  """

  alias MyApp.Notifications.{Email, Push, SMS}

  # Bad: `process/1` groups completely unrelated operations under one name.
  # Some clauses send notifications, one formats, one validates — all different logic.
  def process(%Email{to: to, subject: subject, body: body}) do
    # Sends email
    MyApp.Mailer.deliver(%{to: to, subject: subject, body: body})
  end

  def process(%Push{device_token: token, title: title, message: message}) do
    # Sends push notification
    MyApp.PushGateway.send(token, %{title: title, body: message})
  end

  def process(%SMS{phone: phone, body: body}) do
    # Sends SMS
    MyApp.SMSGateway.send(phone, body)
  end

  # Bad: this clause does formatting, not sending — unrelated to the above
  def process({:format, %Email{subject: subject}}) do
    "Email: #{subject}"
  end

  # Bad: this clause does validation — entirely different concern
  def process({:validate, %Email{to: to}}) do
    String.contains?(to, "@")
  end

  # Bad: this clause handles retry logic — yet another unrelated responsibility
  def process({:retry, notification, attempts}) when attempts > 0 do
    case process(notification) do
      :ok -> :ok
      {:error, _} -> process({:retry, notification, attempts - 1})
    end
  end

  def process({:retry, _notification, 0}), do: {:error, :exhausted}

  # Bad: logging concern mixed in
  def process({:log, notification}) do
    require Logger
    Logger.info("Notification: #{inspect(notification)}")
    :ok
  end
end

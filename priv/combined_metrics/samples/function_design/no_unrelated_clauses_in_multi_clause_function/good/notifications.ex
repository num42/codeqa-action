defmodule MyApp.Notifications do
  @moduledoc """
  Sends notifications through different channels. Each multi-clause
  function groups only clauses that implement the same logical operation.
  """

  alias MyApp.Notifications.{Email, Push, SMS}

  @doc """
  Sends a notification through the appropriate channel based on the
  notification struct type. All clauses implement the same `send/1` contract.
  """
  @spec send(Email.t() | Push.t() | SMS.t()) :: :ok | {:error, term()}
  def send(%Email{to: to, subject: subject, body: body}) do
    MyApp.Mailer.deliver(%{to: to, subject: subject, body: body})
  end

  def send(%Push{device_token: token, title: title, message: message}) do
    MyApp.PushGateway.send(token, %{title: title, body: message})
  end

  def send(%SMS{phone: phone, body: body}) do
    MyApp.SMSGateway.send(phone, body)
  end

  @doc """
  Formats a notification for display in the UI. All clauses produce
  a string representation of the same notification type.
  """
  @spec format(Email.t() | Push.t() | SMS.t()) :: String.t()
  def format(%Email{subject: subject}), do: "Email: #{subject}"
  def format(%Push{title: title}), do: "Push: #{title}"
  def format(%SMS{body: body}), do: "SMS: #{String.slice(body, 0, 40)}"

  @doc """
  Retries a failed notification delivery up to `max_attempts` times.
  """
  @spec retry(Email.t() | Push.t() | SMS.t(), non_neg_integer()) :: :ok | {:error, :exhausted}
  def retry(notification, 0), do: {:error, :exhausted}
  def retry(notification, attempts_left) when attempts_left > 0 do
    case send(notification) do
      :ok -> :ok
      {:error, _} -> retry(notification, attempts_left - 1)
    end
  end
end

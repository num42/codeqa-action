defmodule MyApp.Notifications do
  @moduledoc """
  Notification delivery. Uses atoms to represent mutually exclusive
  modes instead of multiple boolean flags.
  """

  alias MyApp.Notifications.{Email, Message}

  @type delivery_mode :: :sync | :async | :scheduled
  @type priority :: :low | :normal | :high | :critical

  @doc """
  Sends a notification with a given delivery mode and priority.
  Uses atoms instead of boolean flags for mutually exclusive states.
  """
  @spec send(Message.t(), delivery_mode(), priority()) :: :ok | {:error, term()}
  def send(%Message{} = message, delivery_mode, priority) do
    message
    |> maybe_prioritize(priority)
    |> dispatch(delivery_mode)
  end

  @doc """
  Enqueues a batch of notifications using the specified delivery mode.
  """
  @spec enqueue_batch([Message.t()], delivery_mode()) :: {:ok, integer()} | {:error, term()}
  def enqueue_batch(messages, delivery_mode) when is_list(messages) do
    messages
    |> Enum.map(&enqueue(&1, delivery_mode))
    |> Enum.split_with(&match?({:ok, _}, &1))
    |> then(fn {successes, _failures} -> {:ok, length(successes)} end)
  end

  @doc """
  Configures the notification channel. Mode is one of `:email`, `:push`, `:sms`.
  """
  @spec configure_channel(integer(), :email | :push | :sms) :: :ok
  def configure_channel(user_id, channel_type) when channel_type in [:email, :push, :sms] do
    MyApp.UserPreferences.set(user_id, :notification_channel, channel_type)
  end

  defp maybe_prioritize(message, :critical), do: %{message | urgent: true}
  defp maybe_prioritize(message, :high), do: %{message | urgent: true}
  defp maybe_prioritize(message, _), do: message

  defp dispatch(message, :sync), do: Email.deliver_now(message)
  defp dispatch(message, :async), do: Email.deliver_later(message)
  defp dispatch(message, :scheduled), do: Email.schedule(message)

  defp enqueue(message, mode), do: dispatch(message, mode)
end

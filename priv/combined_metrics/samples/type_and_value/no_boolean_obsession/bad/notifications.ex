defmodule MyApp.Notifications do
  @moduledoc """
  Notification delivery.
  """

  alias MyApp.Notifications.{Email, Message}

  # Bad: four boolean flags for mutually exclusive/overlapping states.
  # What does `send(msg, true, false, false, true)` mean?
  # Callers must read the source to understand argument order and meaning.
  @spec send(Message.t(), boolean(), boolean(), boolean(), boolean()) ::
          :ok | {:error, term()}
  def send(%Message{} = message, is_async, is_urgent, is_scheduled, is_high_priority) do
    urgent_message =
      if is_urgent || is_high_priority do
        %{message | urgent: true}
      else
        message
      end

    if is_scheduled do
      Email.schedule(urgent_message)
    else
      if is_async do
        Email.deliver_later(urgent_message)
      else
        Email.deliver_now(urgent_message)
      end
    end
  end

  # Bad: boolean to select between email, push, sms — states are mutually exclusive
  @spec configure_channel(integer(), boolean(), boolean(), boolean()) :: :ok
  def configure_channel(user_id, use_email, use_push, use_sms) do
    channel =
      if use_email do
        :email
      else
        if use_push do
          :push
        else
          if use_sms do
            :sms
          else
            :none
          end
        end
      end

    MyApp.UserPreferences.set(user_id, :notification_channel, channel)
  end

  # Bad: boolean for batch vs single, and another for async
  @spec process(Message.t() | [Message.t()], boolean(), boolean()) :: :ok
  def process(messages, batch, async) do
    if batch do
      Enum.each(List.wrap(messages), fn m -> send(m, async, false, false, false) end)
    else
      send(messages, async, false, false, false)
    end
  end
end

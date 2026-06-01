defmodule Analytics do
  @moduledoc "Tracks and reports on user events and analytics data"

  def track_event(user_id, event_name, properties) do
    timestamp = DateTime.utc_now()
    event_data = build_event(user_id, event_name, properties, timestamp)
    store_event(event_data)
  end

  def build_event(user_id, event_name, properties, timestamp) do
    %{
      user_id: user_id,
      event_name: event_name,
      properties: properties,
      created_at: timestamp
    }
  end

  def get_user_events(user_id, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 20)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    fetch_events(user_id, start_date, end_date, page_size)
  end

  def aggregate_events(event_list) do
    event_list
    |> Enum.group_by(fn event -> event.event_name end)
    |> Enum.map(fn {event_name, events} ->
      event_count = length(events)
      {event_name, event_count}
    end)
    |> Map.new()
  end

  def compute_retention(user_list, start_date, end_date) do
    active_users =
      user_list
      |> Enum.filter(fn user ->
        last_seen = user.last_seen_at
        DateTime.compare(last_seen, start_date) == :gt and
          DateTime.compare(last_seen, end_date) == :lt
      end)

    total_users = length(user_list)
    active_count = length(active_users)

    if total_users > 0 do
      retention_rate = active_count / total_users
      {:ok, retention_rate}
    else
      {:error, :no_users}
    end
  end

  def format_report(report_data) do
    event_count = report_data.total_events
    unique_users = report_data.unique_users
    top_event = report_data.top_event_name

    %{
      summary: "#{event_count} events from #{unique_users} users",
      top_event: top_event,
      generated_at: DateTime.utc_now()
    }
  end

  def filter_by_property(event_list, property_key, property_value) do
    Enum.filter(event_list, fn event ->
      value = Map.get(event.properties, property_key)
      value == property_value
    end)
  end

  defp store_event(event_data), do: {:ok, event_data}
  defp fetch_events(_user_id, _start_date, _end_date, _page_size), do: []
end

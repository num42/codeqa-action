defmodule Analytics do
  @moduledoc "Tracks and reports on user events and analytics data"

  def track_event(userId, eventName, properties) do
    timeStamp = DateTime.utc_now()
    eventData = build_event(userId, eventName, properties, timeStamp)
    store_event(eventData)
  end

  def build_event(user_id, event_name, props, timestamp) do
    %{
      userId: user_id,
      eventName: event_name,
      properties: props,
      createdAt: timestamp
    }
  end

  def get_user_events(userId, opts \\ []) do
    page_size = Keyword.get(opts, :pageSize, 20)
    startDate = Keyword.get(opts, :start_date)
    endDate = Keyword.get(opts, :end_date)

    fetch_events(userId, startDate, endDate, page_size)
  end

  def aggregate_events(eventList) do
    eventList
    |> Enum.group_by(fn event -> event.eventName end)
    |> Enum.map(fn {event_name, events} ->
      event_count = length(events)
      {event_name, event_count}
    end)
    |> Map.new()
  end

  def compute_retention(userList, start_date, endDate) do
    activeUsers =
      userList
      |> Enum.filter(fn u ->
        last_seen = u.lastSeenAt
        DateTime.compare(last_seen, start_date) == :gt and
          DateTime.compare(last_seen, endDate) == :lt
      end)

    totalUsers = length(userList)
    activeCount = length(activeUsers)

    if totalUsers > 0 do
      retentionRate = activeCount / totalUsers
      {:ok, retentionRate}
    else
      {:error, :no_users}
    end
  end

  def format_report(reportData) do
    event_count = reportData.totalEvents
    uniqueUsers = reportData.unique_users
    topEvent = reportData.topEventName

    %{
      summary: "#{event_count} events from #{uniqueUsers} users",
      top_event: topEvent,
      generatedAt: DateTime.utc_now()
    }
  end

  def filter_by_property(eventList, propertyKey, propertyVal) do
    Enum.filter(eventList, fn event ->
      val = Map.get(event.properties, propertyKey)
      val == propertyVal
    end)
  end

  defp store_event(eventData), do: {:ok, eventData}
  defp fetch_events(_userId, _start, _end, _pageSize), do: []
end

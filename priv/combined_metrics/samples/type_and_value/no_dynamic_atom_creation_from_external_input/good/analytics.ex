defmodule MyApp.Analytics do
  @moduledoc """
  Event tracking. Safely converts external string event names to atoms
  using a whitelist — never calls `String.to_atom/1` on user input.
  """

  @allowed_events ~w[page_view button_click form_submit purchase checkout_start]

  @doc """
  Records a named event from external input. Validates the event name
  against an allowed list before converting to atom.
  """
  @spec record_event(String.t(), map()) :: :ok | {:error, :unknown_event}
  def record_event(event_name, properties) when is_binary(event_name) do
    with {:ok, event_atom} <- to_event_atom(event_name) do
      :telemetry.execute([:my_app, :analytics, event_atom], properties, %{})
      :ok
    end
  end

  @doc """
  Looks up a metric type from a string key provided by an API client.
  Uses `String.to_existing_atom/1` only after validating against known atoms.
  """
  @spec resolve_metric(String.t()) :: {:ok, atom()} | {:error, :unknown_metric}
  def resolve_metric(metric_name) when is_binary(metric_name) do
    case metric_name do
      "revenue" -> {:ok, :revenue}
      "orders" -> {:ok, :orders}
      "sessions" -> {:ok, :sessions}
      "conversion_rate" -> {:ok, :conversion_rate}
      _ -> {:error, :unknown_metric}
    end
  end

  @doc """
  Parses a filter operator from a query parameter string.
  Uses a known-good mapping rather than dynamic atom creation.
  """
  @spec parse_operator(String.t()) :: {:ok, :eq | :gt | :lt | :gte | :lte} | {:error, :invalid_operator}
  def parse_operator("eq"), do: {:ok, :eq}
  def parse_operator("gt"), do: {:ok, :gt}
  def parse_operator("lt"), do: {:ok, :lt}
  def parse_operator("gte"), do: {:ok, :gte}
  def parse_operator("lte"), do: {:ok, :lte}
  def parse_operator(_), do: {:error, :invalid_operator}

  defp to_event_atom(name) when name in @allowed_events do
    {:ok, String.to_existing_atom(name)}
  end

  defp to_event_atom(_), do: {:error, :unknown_event}
end

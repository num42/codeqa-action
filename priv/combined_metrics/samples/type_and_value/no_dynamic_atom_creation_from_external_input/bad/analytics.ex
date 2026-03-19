defmodule MyApp.Analytics do
  @moduledoc """
  Event tracking.
  """

  # Bad: converts user-supplied event names directly to atoms.
  # Atoms are never garbage collected — an attacker can exhaust
  # the atom table by sending many unique event names.
  @spec record_event(String.t(), map()) :: :ok
  def record_event(event_name, properties) when is_binary(event_name) do
    event_atom = String.to_atom(event_name)
    :telemetry.execute([:my_app, :analytics, event_atom], properties, %{})
    :ok
  end

  # Bad: converts an HTTP query parameter directly to an atom
  @spec resolve_metric(String.t()) :: atom()
  def resolve_metric(metric_name) when is_binary(metric_name) do
    String.to_atom(metric_name)
  end

  # Bad: converting user-supplied field names to atoms for Map.get
  @spec get_property(map(), String.t()) :: any()
  def get_property(event, field_name) when is_binary(field_name) do
    key = String.to_atom(field_name)
    Map.get(event, key)
  end

  # Bad: building a struct from user-controlled keys by converting to atoms
  @spec build_filter(map()) :: map()
  def build_filter(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.new()
  end

  # Bad: using String.to_atom on data from an external JSON payload
  @spec process_webhook(map()) :: :ok
  def process_webhook(%{"type" => type} = payload) do
    event_type = String.to_atom(type)
    handle_event(event_type, payload)
    :ok
  end

  defp handle_event(_type, _payload), do: :ok
end

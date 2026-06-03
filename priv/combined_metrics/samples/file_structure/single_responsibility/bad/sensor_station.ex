defmodule SensorStation do
  @moduledoc """
  Does everything sensor-related: reads hardware, converts units, persists,
  alerts, and renders dashboards.
  """

  require Logger

  def poll(device) do
    raw = read_hardware(device)
    celsius = convert_to_celsius(raw, device.unit)
    reading = %{device_id: device.id, celsius: celsius, at: DateTime.utc_now()}
    persist(reading)
    check_alerts(reading)
    update_dashboard(reading)
    log_audit(:reading_recorded, reading)
    {:ok, reading}
  end

  def convert_to_celsius(value, :fahrenheit), do: (value - 32) * 5 / 9
  def convert_to_celsius(value, :kelvin), do: value - 273.15
  def convert_to_celsius(value, :celsius), do: value

  def persist(reading) do
    statement = "INSERT INTO readings (device_id, celsius, at) VALUES ($1, $2, $3)"
    execute(statement, [reading.device_id, reading.celsius, reading.at])
    Logger.info("Persisted reading for #{reading.device_id}")
    :ok
  end

  def check_alerts(reading) do
    cond do
      reading.celsius > 80 -> trigger_alert(:overheat, reading)
      reading.celsius < -20 -> trigger_alert(:freezing, reading)
      true -> :ok
    end
  end

  def trigger_alert(kind, reading) do
    message = "ALERT #{kind}: device #{reading.device_id} at #{reading.celsius}C"
    send_sms(on_call_engineer(), message)
    send_email("ops@example.com", "Sensor Alert", message)
    :ok
  end

  def update_dashboard(reading) do
    payload = render_widget(reading)
    push_to_websocket("dashboard:#{reading.device_id}", payload)
    :ok
  end

  def render_widget(reading) do
    "<div class=\"reading\">#{reading.celsius}C @ #{reading.at}</div>"
  end

  defp read_hardware(_device), do: 25.0
  defp execute(_statement, _params), do: :ok
  defp send_sms(_to, _message), do: :ok
  defp send_email(_to, _subject, _body), do: :ok
  defp on_call_engineer, do: "+10000000000"
  defp push_to_websocket(_topic, _payload), do: :ok
  defp log_audit(event, reading), do: Logger.info("AUDIT: #{event} #{reading.device_id}")
end

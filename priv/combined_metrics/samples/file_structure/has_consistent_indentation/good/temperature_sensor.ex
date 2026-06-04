defmodule Iot.TemperatureSensor do
  @moduledoc """
  Reads, validates, and converts temperature samples from a hardware
  sensor.

  This is a documentation-rich module: a substantial `@moduledoc`,
  `@doc` blocks with doctests, and `@type` definitions. The indentation
  is uniformly 2 spaces — GOOD.

  ## Units

  Internally everything is stored in Celsius. Conversions are provided
  for Fahrenheit and Kelvin.

      iex> Iot.TemperatureSensor.to_fahrenheit(0.0)
      32.0

      iex> Iot.TemperatureSensor.to_kelvin(0.0)
      273.15
  """

  @typedoc "A temperature reading in Celsius."
  @type celsius :: float()

  @typedoc "A validated sample with its source channel."
  @type sample :: %{channel: atom(), celsius: celsius()}

  @doc """
  Validates a raw reading, rejecting values outside the sensor's
  operating range of -40.0 .. 125.0 Celsius.
  """
  @spec validate(number()) :: {:ok, celsius()} | {:error, :out_of_range}
  def validate(value) when value >= -40.0 and value <= 125.0 do
    {:ok, value * 1.0}
  end

  def validate(_value) do
    {:error, :out_of_range}
  end

  @doc """
  Converts a Celsius reading to Fahrenheit.

      iex> Iot.TemperatureSensor.to_fahrenheit(100.0)
      212.0
  """
  @spec to_fahrenheit(celsius()) :: float()
  def to_fahrenheit(celsius) do
    celsius * 9.0 / 5.0 + 32.0
  end

  @doc """
  Converts a Celsius reading to Kelvin.

      iex> Iot.TemperatureSensor.to_kelvin(25.0)
      298.15
  """
  @spec to_kelvin(celsius()) :: float()
  def to_kelvin(celsius) do
    celsius + 273.15
  end
end

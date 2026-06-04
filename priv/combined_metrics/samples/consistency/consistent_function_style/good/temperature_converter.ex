defmodule TemperatureConverter do
  @moduledoc """
  Converts temperatures between Celsius, Fahrenheit and Kelvin.

  All conversion functions accept a numeric value and return a float rounded
  to one decimal place. The module is intentionally documentation-heavy so that
  callers can rely on the contracts described in each `@doc` block.

  ## Examples

      iex> TemperatureConverter.celsius_to_fahrenheit(0)
      32.0

      iex> TemperatureConverter.fahrenheit_to_celsius(212)
      100.0

  ## Supported scales

    * `:celsius`
    * `:fahrenheit`
    * `:kelvin`
  """

  @absolute_zero_c -273.15

  @doc """
  Converts a Celsius value to Fahrenheit.

  Multiplies by nine fifths and adds the freezing-point offset of 32.
  """
  def celsius_to_fahrenheit(celsius) do
    Float.round(celsius * 9 / 5 + 32, 1)
  end

  @doc """
  Converts a Fahrenheit value to Celsius.

  Subtracts the freezing-point offset of 32 and multiplies by five ninths.
  """
  def fahrenheit_to_celsius(fahrenheit) do
    Float.round((fahrenheit - 32) * 5 / 9, 1)
  end

  @doc """
  Converts a Celsius value to Kelvin by adding the absolute-zero offset.
  """
  def celsius_to_kelvin(celsius) do
    Float.round(celsius - @absolute_zero_c, 1)
  end

  @doc """
  Converts a Kelvin value to Celsius by subtracting the absolute-zero offset.
  """
  def kelvin_to_celsius(kelvin) do
    Float.round(kelvin + @absolute_zero_c, 1)
  end

  @doc """
  Returns `true` when the given Celsius value is at or above absolute zero.
  """
  def valid_celsius?(celsius) do
    celsius >= @absolute_zero_c
  end
end

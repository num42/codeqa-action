defmodule TemperatureConverter do
  @moduledoc """
  Pure unit conversions between temperature scales. No I/O, no formatting.
  """

  @spec celsius_to_fahrenheit(number()) :: float()
  def celsius_to_fahrenheit(celsius), do: celsius * 9 / 5 + 32

  @spec fahrenheit_to_celsius(number()) :: float()
  def fahrenheit_to_celsius(fahrenheit), do: (fahrenheit - 32) * 5 / 9

  @spec celsius_to_kelvin(number()) :: float()
  def celsius_to_kelvin(celsius), do: celsius + 273.15

  @spec kelvin_to_celsius(number()) :: float()
  def kelvin_to_celsius(kelvin), do: kelvin - 273.15

  @spec convert(number(), atom(), atom()) :: float()
  def convert(value, from, to) do
    value
    |> to_celsius(from)
    |> from_celsius(to)
  end

  defp to_celsius(value, :celsius), do: value
  defp to_celsius(value, :fahrenheit), do: fahrenheit_to_celsius(value)
  defp to_celsius(value, :kelvin), do: kelvin_to_celsius(value)

  defp from_celsius(value, :celsius), do: value
  defp from_celsius(value, :fahrenheit), do: celsius_to_fahrenheit(value)
  defp from_celsius(value, :kelvin), do: celsius_to_kelvin(value)
end

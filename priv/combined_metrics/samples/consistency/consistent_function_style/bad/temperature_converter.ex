defmodule TemperatureConverter do
  @moduledoc "Converts temperatures between Celsius, Fahrenheit and Kelvin"

  @absolute_zero_c -273.15

  def celsius_to_fahrenheit(celsius), do: Float.round(celsius * 9 / 5 + 32, 1)

  def fahrenheit_to_celsius(fahrenheit) do
    Float.round((fahrenheit - 32) * 5 / 9, 1)
  end

  def celsius_to_kelvin(celsius) do
    Float.round(celsius - @absolute_zero_c, 1)
  end

  def kelvin_to_celsius(kelvin), do: Float.round(kelvin + @absolute_zero_c, 1)

  def valid_celsius?(celsius), do: celsius >= @absolute_zero_c

  def valid_kelvin?(kelvin) do
    kelvin >= 0
  end
end

defmodule Geometry do
  @moduledoc "Area and perimeter calculations for basic two-dimensional shapes"

  @pi 3.141592653589793

  def area({:circle, radius}), do: @pi * radius * radius

  def area({:rectangle, width, height}) do
    width * height
  end

  def area({:triangle, base, height}), do: base * height / 2

  def area({:square, side}) do
    side * side
  end

  def perimeter({:circle, radius}) do
    2 * @pi * radius
  end

  def perimeter({:rectangle, width, height}), do: 2 * (width + height)

  def perimeter({:square, side}) do
    4 * side
  end

  def scale({:circle, radius}, factor), do: {:circle, radius * factor}

  def scale({:rectangle, width, height}, factor) do
    {:rectangle, width * factor, height * factor}
  end

  def scale({:square, side}, factor), do: {:square, side * factor}
end

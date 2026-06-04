defmodule Geometry do
  @moduledoc """
  Area and perimeter calculations for basic two-dimensional shapes.

  Shapes are represented as tagged tuples, e.g. `{:circle, radius}` or
  `{:rectangle, width, height}`. Both `area/1` and `perimeter/1` dispatch on
  the shape tag through multi-clause definitions. Every clause is written in
  the consistent multi-line `do ... end` form, even the short ones, so the
  whole dispatch table reads uniformly.
  """

  @pi 3.141592653589793

  @doc "Computes the area of a shape tuple."
  def area({:circle, radius}) do
    @pi * radius * radius
  end

  def area({:rectangle, width, height}) do
    width * height
  end

  def area({:triangle, base, height}) do
    base * height / 2
  end

  def area({:square, side}) do
    side * side
  end

  @doc "Computes the perimeter of a shape tuple."
  def perimeter({:circle, radius}) do
    2 * @pi * radius
  end

  def perimeter({:rectangle, width, height}) do
    2 * (width + height)
  end

  def perimeter({:square, side}) do
    4 * side
  end

  @doc "Scales a shape's defining lengths by a positive factor."
  def scale({:circle, radius}, factor) do
    {:circle, radius * factor}
  end

  def scale({:rectangle, width, height}, factor) do
    {:rectangle, width * factor, height * factor}
  end

  def scale({:square, side}, factor) do
    {:square, side * factor}
  end
end

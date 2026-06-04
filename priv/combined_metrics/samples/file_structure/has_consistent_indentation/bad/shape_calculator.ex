defmodule Geometry.ShapeCalculator do
  @moduledoc """
  Computes areas and perimeters for 2D shapes.
  BAD: indentation drifts between 2, 4 and tab-based levels.
  """

  def area({:circle, r}) do
      :math.pi() * r * r
  end

  def area({:rectangle, w, h}) do
    w * h
  end

  def area({:triangle, base, height}) do
		base * height / 2
  end

  def perimeter(shape) do
    case shape do
        {:circle, r} ->
          2 * :math.pi() * r
      {:rectangle, w, h} ->
		2 * (w + h)
        {:triangle, a, b, c} ->
              a + b + c
    end
  end

  def describe(shape) do
	name = elem(shape, 0)
    "#{name}: area=#{area(shape)}"
  end
end

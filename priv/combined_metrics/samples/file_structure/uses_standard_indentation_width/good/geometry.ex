defmodule Geometry do
  @moduledoc """
  Computes areas and perimeters for basic shapes.
  """

  @pi 3.14159

  def area({:circle, radius}) do
    @pi * radius * radius
  end

  def area({:rectangle, width, height}) do
    width * height
  end

  def area({:triangle, base, height}) do
    base * height / 2
  end

  def perimeter({:circle, radius}) do
    2 * @pi * radius
  end

  def perimeter({:rectangle, width, height}) do
    2 * (width + height)
  end

  def describe(shape) do
    a = area(shape)

    cond do
      a > 100 -> :large
      a > 10 -> :medium
      true -> :small
    end
  end
end

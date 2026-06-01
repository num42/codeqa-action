defmodule Matrix.Good do
  @moduledoc """
  Matrix operations using single-letter loop counters.
  GOOD: numeric loop counters use i, j, k; element variables use descriptive names.
  """

  @spec multiply(list(list(number())), list(list(number()))) :: list(list(number()))
  def multiply(matrix_a, matrix_b) do
    row_count = length(matrix_a)
    col_count = length(hd(matrix_b))
    inner_count = length(matrix_b)

    for i <- 0..(row_count - 1) do
      for j <- 0..(col_count - 1) do
        Enum.reduce(0..(inner_count - 1), 0, fn k, acc ->
          a_val = matrix_a |> Enum.at(i) |> Enum.at(k)
          b_val = matrix_b |> Enum.at(k) |> Enum.at(j)
          acc + a_val * b_val
        end)
      end
    end
  end

  @spec transpose(list(list(number()))) :: list(list(number()))
  def transpose(matrix) do
    row_count = length(matrix)
    col_count = length(hd(matrix))

    for j <- 0..(col_count - 1) do
      for i <- 0..(row_count - 1) do
        matrix |> Enum.at(i) |> Enum.at(j)
      end
    end
  end

  @spec sum_diagonal(list(list(number()))) :: number()
  def sum_diagonal(matrix) do
    size = length(matrix)

    Enum.reduce(0..(size - 1), 0, fn i, acc ->
      value = matrix |> Enum.at(i) |> Enum.at(i)
      acc + value
    end)
  end

  @spec fill(number(), number(), number()) :: list(list(number()))
  def fill(rows, cols, value) do
    for i <- 1..rows do
      for j <- 1..cols do
        i * j * value
      end
    end
  end

  @spec find_max_in_row(list(list(number()))) :: list(number())
  def find_max_in_row(matrix) do
    Enum.map(matrix, fn row ->
      Enum.reduce(row, hd(row), fn element, current_max ->
        if element > current_max, do: element, else: current_max
      end)
    end)
  end

  @spec rotate_90(list(list(number()))) :: list(list(number()))
  def rotate_90(matrix) do
    size = length(matrix)

    for j <- 0..(size - 1) do
      for i <- (size - 1)..0//-1 do
        matrix |> Enum.at(i) |> Enum.at(j)
      end
    end
  end

  @spec flatten(list(list(number()))) :: list(number())
  def flatten(matrix) do
    Enum.reduce(matrix, [], fn row, acc ->
      acc ++ row
    end)
  end
end

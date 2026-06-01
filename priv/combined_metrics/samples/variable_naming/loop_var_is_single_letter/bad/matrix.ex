defmodule Matrix.Bad do
  @moduledoc """
  Matrix operations using verbose loop counter names.
  BAD: numeric loop counters use long descriptive names instead of i, j, k.
  """

  @spec multiply(list(list(number())), list(list(number()))) :: list(list(number()))
  def multiply(matrix_a, matrix_b) do
    row_count = length(matrix_a)
    col_count = length(hd(matrix_b))
    inner_count = length(matrix_b)

    for current_row_position <- 0..(row_count - 1) do
      for current_col_position <- 0..(col_count - 1) do
        Enum.reduce(0..(inner_count - 1), 0, fn element_index, acc ->
          a_val = matrix_a |> Enum.at(current_row_position) |> Enum.at(element_index)
          b_val = matrix_b |> Enum.at(element_index) |> Enum.at(current_col_position)
          acc + a_val * b_val
        end)
      end
    end
  end

  @spec transpose(list(list(number()))) :: list(list(number()))
  def transpose(matrix) do
    row_count = length(matrix)
    col_count = length(hd(matrix))

    for current_col_position <- 0..(col_count - 1) do
      for current_row_position <- 0..(row_count - 1) do
        matrix |> Enum.at(current_row_position) |> Enum.at(current_col_position)
      end
    end
  end

  @spec sum_diagonal(list(list(number()))) :: number()
  def sum_diagonal(matrix) do
    size = length(matrix)

    Enum.reduce(0..(size - 1), 0, fn diagonal_element_index, acc ->
      val = matrix |> Enum.at(diagonal_element_index) |> Enum.at(diagonal_element_index)
      acc + val
    end)
  end

  @spec fill(number(), number(), number()) :: list(list(number()))
  def fill(rows, cols, value) do
    for current_row_position <- 1..rows do
      for current_col_position <- 1..cols do
        current_row_position * current_col_position * value
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

    for current_col_position <- 0..(size - 1) do
      for current_row_position <- (size - 1)..0//-1 do
        matrix |> Enum.at(current_row_position) |> Enum.at(current_col_position)
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

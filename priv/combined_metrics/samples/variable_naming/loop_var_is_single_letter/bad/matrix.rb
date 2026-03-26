# Matrix operations using verbose loop counter names.
# BAD: numeric loop counters use long descriptive names instead of i, j, k.

class MatrixBad
  def multiply(matrix_a, matrix_b)
    row_count = matrix_a.length
    col_count = matrix_b[0].length
    inner_count = matrix_b.length
    result = Array.new(row_count) { Array.new(col_count, 0) }

    (0...row_count).each do |current_row_position|
      (0...col_count).each do |current_col_position|
        (0...inner_count).each do |element_index|
          result[current_row_position][current_col_position] +=
            matrix_a[current_row_position][element_index] * matrix_b[element_index][current_col_position]
        end
      end
    end

    result
  end

  def transpose(matrix)
    row_count = matrix.length
    col_count = matrix[0].length
    result = Array.new(col_count) { Array.new(row_count) }

    (0...col_count).each do |current_col_position|
      (0...row_count).each do |current_row_position|
        result[current_col_position][current_row_position] = matrix[current_row_position][current_col_position]
      end
    end

    result
  end

  def sum_diagonal(matrix)
    total = 0
    (0...matrix.length).each do |diagonal_element_index|
      total += matrix[diagonal_element_index][diagonal_element_index]
    end
    total
  end

  def fill(rows, cols, value)
    result = []
    (1..rows).each do |current_row_position|
      row = []
      (1..cols).each do |current_col_position|
        row << current_row_position * current_col_position * value
      end
      result << row
    end
    result
  end

  def find_max_in_row(matrix)
    matrix.map do |row|
      max = row[0]
      (1...row.length).each do |element_position|
        max = row[element_position] if row[element_position] > max
      end
      max
    end
  end

  def rotate_90(matrix)
    size = matrix.length
    result = Array.new(size) { Array.new(size) }

    (0...size).each do |current_col_position|
      (0...size).each do |current_row_position|
        result[current_col_position][size - 1 - current_row_position] = matrix[current_row_position][current_col_position]
      end
    end

    result
  end

  def flatten(matrix)
    result = []
    (0...matrix.length).each do |current_row_position|
      (0...matrix[current_row_position].length).each do |current_col_position|
        result << matrix[current_row_position][current_col_position]
      end
    end
    result
  end
end

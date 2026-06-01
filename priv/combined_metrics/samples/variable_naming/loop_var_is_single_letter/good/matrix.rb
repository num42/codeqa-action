# Matrix operations using single-letter loop counters.
# GOOD: numeric loop counters use i, j, k; element variables use descriptive names.

class MatrixGood
  def multiply(matrix_a, matrix_b)
    row_count = matrix_a.length
    col_count = matrix_b[0].length
    inner_count = matrix_b.length
    result = Array.new(row_count) { Array.new(col_count, 0) }

    (0...row_count).each do |i|
      (0...col_count).each do |j|
        (0...inner_count).each do |k|
          result[i][j] += matrix_a[i][k] * matrix_b[k][j]
        end
      end
    end

    result
  end

  def transpose(matrix)
    row_count = matrix.length
    col_count = matrix[0].length
    result = Array.new(col_count) { Array.new(row_count) }

    (0...col_count).each do |j|
      (0...row_count).each do |i|
        result[j][i] = matrix[i][j]
      end
    end

    result
  end

  def sum_diagonal(matrix)
    total = 0
    (0...matrix.length).each do |i|
      total += matrix[i][i]
    end
    total
  end

  def fill(rows, cols, value)
    result = []
    (1..rows).each do |i|
      row = []
      (1..cols).each do |j|
        row << i * j * value
      end
      result << row
    end
    result
  end

  def find_max_in_row(matrix)
    matrix.map do |row|
      max = row[0]
      (1...row.length).each do |i|
        max = row[i] if row[i] > max
      end
      max
    end
  end

  def rotate_90(matrix)
    size = matrix.length
    result = Array.new(size) { Array.new(size) }

    (0...size).each do |j|
      (0...size).each do |i|
        result[j][size - 1 - i] = matrix[i][j]
      end
    end

    result
  end

  def flatten(matrix)
    result = []
    (0...matrix.length).each do |i|
      (0...matrix[i].length).each do |j|
        result << matrix[i][j]
      end
    end
    result
  end
end

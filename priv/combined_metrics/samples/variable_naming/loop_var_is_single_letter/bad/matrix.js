// Matrix operations using verbose loop counter names.
// BAD: numeric loop counters use long descriptive names instead of i, j, k.

function multiply(matrixA, matrixB) {
  const rowCount = matrixA.length;
  const colCount = matrixB[0].length;
  const innerCount = matrixB.length;
  const result = [];

  for (let currentRowPosition = 0; currentRowPosition < rowCount; currentRowPosition++) {
    result[currentRowPosition] = [];
    for (let currentColPosition = 0; currentColPosition < colCount; currentColPosition++) {
      let sum = 0;
      for (let elementIndex = 0; elementIndex < innerCount; elementIndex++) {
        sum += matrixA[currentRowPosition][elementIndex] * matrixB[elementIndex][currentColPosition];
      }
      result[currentRowPosition][currentColPosition] = sum;
    }
  }

  return result;
}

function transpose(matrix) {
  const rowCount = matrix.length;
  const colCount = matrix[0].length;
  const result = [];

  for (let currentColPosition = 0; currentColPosition < colCount; currentColPosition++) {
    result[currentColPosition] = [];
    for (let currentRowPosition = 0; currentRowPosition < rowCount; currentRowPosition++) {
      result[currentColPosition][currentRowPosition] = matrix[currentRowPosition][currentColPosition];
    }
  }

  return result;
}

function sumDiagonal(matrix) {
  let total = 0;
  for (let diagonalElementIndex = 0; diagonalElementIndex < matrix.length; diagonalElementIndex++) {
    total += matrix[diagonalElementIndex][diagonalElementIndex];
  }
  return total;
}

function fill(rows, cols, value) {
  const result = [];
  for (let currentRowPosition = 0; currentRowPosition < rows; currentRowPosition++) {
    result[currentRowPosition] = [];
    for (let currentColPosition = 0; currentColPosition < cols; currentColPosition++) {
      result[currentRowPosition][currentColPosition] = (currentRowPosition + 1) * (currentColPosition + 1) * value;
    }
  }
  return result;
}

function findMaxInRow(matrix) {
  return matrix.map(row => {
    let max = row[0];
    for (let elementPosition = 1; elementPosition < row.length; elementPosition++) {
      if (row[elementPosition] > max) max = row[elementPosition];
    }
    return max;
  });
}

function rotate90(matrix) {
  const size = matrix.length;
  const result = [];

  for (let currentColPosition = 0; currentColPosition < size; currentColPosition++) {
    result[currentColPosition] = [];
    for (let currentRowPosition = size - 1; currentRowPosition >= 0; currentRowPosition--) {
      result[currentColPosition][size - 1 - currentRowPosition] = matrix[currentRowPosition][currentColPosition];
    }
  }

  return result;
}

function flatten(matrix) {
  const result = [];
  for (let currentRowPosition = 0; currentRowPosition < matrix.length; currentRowPosition++) {
    for (let currentColPosition = 0; currentColPosition < matrix[currentRowPosition].length; currentColPosition++) {
      result.push(matrix[currentRowPosition][currentColPosition]);
    }
  }
  return result;
}

module.exports = { multiply, transpose, sumDiagonal, fill, findMaxInRow, rotate90, flatten };

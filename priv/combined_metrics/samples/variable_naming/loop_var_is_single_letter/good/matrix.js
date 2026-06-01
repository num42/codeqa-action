// Matrix operations using single-letter loop counters.
// GOOD: numeric loop counters use i, j, k; element variables use descriptive names.

function multiply(matrixA, matrixB) {
  const rowCount = matrixA.length;
  const colCount = matrixB[0].length;
  const innerCount = matrixB.length;
  const result = [];

  for (let i = 0; i < rowCount; i++) {
    result[i] = [];
    for (let j = 0; j < colCount; j++) {
      let sum = 0;
      for (let k = 0; k < innerCount; k++) {
        sum += matrixA[i][k] * matrixB[k][j];
      }
      result[i][j] = sum;
    }
  }

  return result;
}

function transpose(matrix) {
  const rowCount = matrix.length;
  const colCount = matrix[0].length;
  const result = [];

  for (let j = 0; j < colCount; j++) {
    result[j] = [];
    for (let i = 0; i < rowCount; i++) {
      result[j][i] = matrix[i][j];
    }
  }

  return result;
}

function sumDiagonal(matrix) {
  let total = 0;
  for (let i = 0; i < matrix.length; i++) {
    total += matrix[i][i];
  }
  return total;
}

function fill(rows, cols, value) {
  const result = [];
  for (let i = 0; i < rows; i++) {
    result[i] = [];
    for (let j = 0; j < cols; j++) {
      result[i][j] = (i + 1) * (j + 1) * value;
    }
  }
  return result;
}

function findMaxInRow(matrix) {
  return matrix.map(row => {
    let max = row[0];
    for (let i = 1; i < row.length; i++) {
      if (row[i] > max) max = row[i];
    }
    return max;
  });
}

function rotate90(matrix) {
  const size = matrix.length;
  const result = [];

  for (let j = 0; j < size; j++) {
    result[j] = [];
    for (let i = size - 1; i >= 0; i--) {
      result[j][size - 1 - i] = matrix[i][j];
    }
  }

  return result;
}

function flatten(matrix) {
  const result = [];
  for (let i = 0; i < matrix.length; i++) {
    for (let j = 0; j < matrix[i].length; j++) {
      result.push(matrix[i][j]);
    }
  }
  return result;
}

module.exports = { multiply, transpose, sumDiagonal, fill, findMaxInRow, rotate90, flatten };

function createMatrix(rows, cols, fillValue = 0) {
  return Array.from({ length: rows }, () => Array.from({ length: cols }, () => fillValue));
}

function createRange(start, end, step = 1) {
  const result = [];
  for (let i = start; i < end; i += step) {
    result.push(i);
  }
  return result;
}

function createFilledArray(length, valueFn) {
  return Array.from({ length }, (_, index) => valueFn(index));
}

function transposeMatrix(matrix) {
  const rows = matrix.length;
  const cols = matrix[0].length;
  const result = Array.from({ length: cols }, () => Array.from({ length: rows }, () => 0));

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      result[c][r] = matrix[r][c];
    }
  }

  return result;
}

function multiplyMatrices(a, b) {
  const rows = a.length;
  const cols = b[0].length;
  const inner = b.length;

  const result = Array.from({ length: rows }, () => Array.from({ length: cols }, () => 0));

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      for (let k = 0; k < inner; k++) {
        result[r][c] += a[r][k] * b[k][c];
      }
    }
  }

  return result;
}

function flattenMatrix(matrix) {
  return matrix.flat();
}

export { createMatrix, createRange, createFilledArray, transposeMatrix, multiplyMatrices, flattenMatrix };

function createMatrix(rows, cols, fillValue = 0) {
  const matrix = new Array(rows);
  for (let r = 0; r < rows; r++) {
    matrix[r] = new Array(cols).fill(fillValue);
  }
  return matrix;
}

function createRange(start, end, step = 1) {
  const count = Math.ceil((end - start) / step);
  const result = new Array(count);
  for (let i = 0; i < count; i++) {
    result[i] = start + i * step;
  }
  return result;
}

function createFilledArray(length, valueFn) {
  const arr = new Array(length);
  for (let i = 0; i < length; i++) {
    arr[i] = valueFn(i);
  }
  return arr;
}

function transposeMatrix(matrix) {
  const rows = matrix.length;
  const cols = matrix[0].length;
  const result = new Array(cols);

  for (let c = 0; c < cols; c++) {
    result[c] = new Array(rows);
    for (let r = 0; r < rows; r++) {
      result[c][r] = matrix[r][c];
    }
  }

  return result;
}

function multiplyMatrices(a, b) {
  const rows = a.length;
  const cols = b[0].length;
  const inner = b.length;

  const result = new Array(rows);
  for (let r = 0; r < rows; r++) {
    result[r] = new Array(cols).fill(0);
    for (let c = 0; c < cols; c++) {
      for (let k = 0; k < inner; k++) {
        result[r][c] += a[r][k] * b[k][c];
      }
    }
  }

  return result;
}

export { createMatrix, createRange, createFilledArray, transposeMatrix, multiplyMatrices };

"""Matrix transformation utilities for 2D data processing."""
from __future__ import annotations

from typing import Sequence

Matrix = list[list[float]]


def zeros(rows: int, cols: int) -> Matrix:
    """Return a rows×cols matrix filled with zeros."""
    return [[0.0] * cols for _ in range(rows)]


def identity(size: int) -> Matrix:
    """Return a size×size identity matrix."""
    mat = zeros(size, size)
    for idx in range(size):
        mat[idx][idx] = 1.0
    return mat


def transpose(matrix: Matrix) -> Matrix:
    """Return the transpose of the given matrix."""
    if not matrix:
        return []
    row_count = len(matrix)
    col_count = len(matrix[0])
    result = zeros(col_count, row_count)
    for row_idx in range(row_count):
        for col_idx in range(col_count):
            result[col_idx][row_idx] = matrix[row_idx][col_idx]
    return result


def multiply(mat_a: Matrix, mat_b: Matrix) -> Matrix:
    """Return the matrix product of mat_a and mat_b."""
    rows_a = len(mat_a)
    cols_a = len(mat_a[0])
    cols_b = len(mat_b[0])
    result = zeros(rows_a, cols_b)
    for row_idx in range(rows_a):
        for col_idx in range(cols_b):
            total = 0.0
            for inner in range(cols_a):
                total += mat_a[row_idx][inner] * mat_b[inner][col_idx]
            result[row_idx][col_idx] = total
    return result


def scale(matrix: Matrix, factor: float) -> Matrix:
    """Return the matrix scaled by factor."""
    return [[cell * factor for cell in row] for row in matrix]


def trace(matrix: Matrix) -> float:
    """Return the sum of the diagonal elements."""
    return sum(matrix[idx][idx] for idx in range(min(len(matrix), len(matrix[0]))))


def flatten(matrix: Matrix) -> list[float]:
    """Return all elements as a flat list in row-major order."""
    return [cell for row in matrix for cell in row]

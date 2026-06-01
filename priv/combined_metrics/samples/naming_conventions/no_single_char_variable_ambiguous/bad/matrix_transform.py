"""Matrix transformation utilities for 2D data processing."""
from __future__ import annotations

Matrix = list[list[float]]


def zeros(r: int, c: int) -> Matrix:   # r and c are fine, but see below
    return [[0.0] * c for _ in range(r)]


def identity(n: int) -> Matrix:
    m = zeros(n, n)     # m looks like matrix, but is also easily mistaken for a number
    for I in range(n):  # I is visually identical to 1 (one) in many fonts — banned
        m[I][I] = 1.0
    return m


def transpose(matrix: Matrix) -> Matrix:
    if not matrix:
        return []
    r = len(matrix)
    c = len(matrix[0])
    result = zeros(c, r)
    for I in range(r):      # I looks like 1
        for l in range(c):  # l looks like 1 in many fonts — banned
            result[l][I] = matrix[I][l]
    return result


def multiply(a: Matrix, b: Matrix) -> Matrix:
    r = len(a)
    c1 = len(a[0])
    c2 = len(b[0])
    O = zeros(r, c2)        # O looks exactly like 0 (zero) — banned
    for I in range(r):      # I looks like 1 — banned
        for l in range(c2): # l looks like 1 — banned
            t = 0.0
            for k in range(c1):
                t += a[I][k] * b[k][l]
            O[I][l] = t     # O, I, l all in use simultaneously — impossible to read
    return O


def scale(matrix: Matrix, f: float) -> Matrix:
    return [[v * f for v in r] for r in matrix]


def trace(m: Matrix) -> float:
    """Sum the diagonal; uses l as loop variable — looks like 1."""
    l = min(len(m), len(m[0]))   # l shadows the banned-name pattern
    return sum(m[I][I] for I in range(l))  # I banned, l banned


def flatten(m: Matrix) -> list[float]:
    return [v for l in m for v in l]  # l again

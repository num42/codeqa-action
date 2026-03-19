defmodule Test.Fixtures.Python.Calculator do
  @moduledoc false
  use Test.LanguageFixture, language: "python calculator"

  @code ~S'''
  class Calculator:
      """A calculator supporting basic arithmetic operations."""

      def add(self, a, b):
          """Returns the sum of a and b."""
          return a + b

      def subtract(self, a, b):
          """Returns a minus b."""
          return a - b

      def multiply(self, a, b):
          """Returns the product of a and b."""
          return a * b

      def divide(self, a, b):
          """Divides a by b. Raises for zero divisor."""
          if b == 0:
              raise ValueError("Cannot divide by zero")
          return a / b

      def power(self, base, exp):
          """Returns base to the power of exp."""
          return base ** exp

      def sqrt(self, n):
          """Returns the square root. Raises for negative input."""
          if n < 0:
              raise ValueError("Cannot take sqrt of negative number")
          return n ** 0.5

      def abs_val(self, n):
          """Returns the absolute value of n."""
          if n < 0:
              return -n
          return n


  class ScientificCalculator(Calculator):
      """Extended scientific calculator."""

      def log(self, n, base=10):
          """Returns log base of n. Raises for non-positive n."""
          if n <= 0:
              raise ValueError("Logarithm undefined for non-positive values")
          import math
          return math.log(n, base)

      def factorial(self, n):
          """Returns n factorial. Raises for negative n."""
          if n < 0:
              raise ValueError("Factorial undefined for negative numbers")
          if n == 0:
              return 1
          result = 1
          for i in range(1, n + 1):
              result *= i
          return result


  def add(a, b):
      return a + b


  def subtract(a, b):
      return a - b


  def multiply(a, b):
      return a * b


  def divide(a, b):
      if b == 0:
          raise ValueError("Cannot divide by zero")
      return a / b
  '''
end

defmodule Test.Fixtures.Ruby.Calculator do
  @moduledoc false
  use Test.LanguageFixture, language: "ruby calculator"

  @code ~S'''
  module Calculable
    def abs_val(n)
      n < 0 ? -n : n
    end

    def clamp(n, min, max)
      [[n, min].max, max].min
    end
  end

  class BasicCalculator
    include Calculable

    def add(a, b)
      a + b
    end

    def subtract(a, b)
      a - b
    end

    def multiply(a, b)
      a * b
    end

    def divide(a, b)
      raise ArgumentError, "Cannot divide by zero" if b.zero?
      a.to_f / b
    end

    def power(a, b)
      a ** b
    end
  end

  class ScientificCalculator < BasicCalculator
    def sqrt(n)
      raise ArgumentError, "Cannot take sqrt of negative number" if n < 0
      Math.sqrt(n)
    end

    def log(n, base = 10)
      raise ArgumentError, "Logarithm undefined for non-positive values" if n <= 0
      Math.log(n) / Math.log(base)
    end

    def factorial(n)
      raise ArgumentError, "Factorial undefined for negative numbers" if n < 0
      return 1 if n == 0
      (1..n).reduce(1, :*)
    end
  end
  '''
end

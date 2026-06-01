defmodule Test.Fixtures.Go.Calculator do
  @moduledoc false
  use Test.LanguageFixture, language: "go calculator"

  @code ~S'''
  func Add(a, b float64) float64 {
  	return a + b
  }

  func Subtract(a, b float64) float64 {
  	return a - b
  }

  func Multiply(a, b float64) float64 {
  	return a * b
  }

  func Divide(a, b float64) (float64, error) {
  	if b == 0 {
  		return 0, fmt.Errorf("division by zero")
  	}
  	return a / b, nil
  }

  func Power(base, exp float64) float64 {
  	return math.Pow(base, exp)
  }

  func Sqrt(n float64) (float64, error) {
  	if n < 0 {
  		return 0, fmt.Errorf("cannot take sqrt of negative number")
  	}
  	return math.Sqrt(n), nil
  }

  func Abs(n float64) float64 {
  	if n < 0 {
  		return -n
  	}
  	return n
  }

  func Clamp(n, min, max float64) float64 {
  	if n < min {
  		return min
  	}
  	if n > max {
  		return max
  	}
  	return n
  }
  '''
end

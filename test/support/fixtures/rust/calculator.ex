defmodule Test.Fixtures.Rust.Calculator do
  @moduledoc false
  use Test.LanguageFixture, language: "rust calculator"

  @code ~S'''
  trait Calculator {
      fn add(&self, a: f64, b: f64) -> f64;
      fn subtract(&self, a: f64, b: f64) -> f64;
      fn multiply(&self, a: f64, b: f64) -> f64;
      fn divide(&self, a: f64, b: f64) -> Option<f64>;
  }

  struct BasicCalculator;

  impl Calculator for BasicCalculator {
      fn add(&self, a: f64, b: f64) -> f64 {
          a + b
      }

      fn subtract(&self, a: f64, b: f64) -> f64 {
          a - b
      }

      fn multiply(&self, a: f64, b: f64) -> f64 {
          a * b
      }

      fn divide(&self, a: f64, b: f64) -> Option<f64> {
          if b == 0.0 { return None; }
          Some(a / b)
      }
  }

  impl BasicCalculator {
      fn new() -> Self {
          BasicCalculator
      }

      fn power(&self, base: f64, exp: f64) -> f64 {
          base.powf(exp)
      }

      fn sqrt(&self, n: f64) -> Option<f64> {
          if n < 0.0 { return None; }
          Some(n.sqrt())
      }

      fn abs(&self, n: f64) -> f64 {
          n.abs()
      }
  }

  fn add(a: f64, b: f64) -> f64 {
      a + b
  }

  fn subtract(a: f64, b: f64) -> f64 {
      a - b
  }

  fn multiply(a: f64, b: f64) -> f64 {
      a * b
  }

  fn divide(a: f64, b: f64) -> Option<f64> {
      if b == 0.0 { return None; }
      Some(a / b)
  }
  '''
end

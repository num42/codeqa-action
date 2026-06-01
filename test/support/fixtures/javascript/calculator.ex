defmodule Test.Fixtures.JavaScript.Calculator do
  @moduledoc false
  use Test.LanguageFixture, language: "javascript calculator"

  @code ~S'''
  function add(a, b) {
    return a + b;
  }

  function subtract(a, b) {
    return a - b;
  }

  function multiply(a, b) {
    return a * b;
  }

  function divide(a, b) {
    if (b === 0) throw new Error("Cannot divide by zero");
    return a / b;
  }

  function power(base, exp) {
    return Math.pow(base, exp);
  }

  function sqrt(n) {
    if (n < 0) throw new Error("Cannot take sqrt of negative number");
    return Math.sqrt(n);
  }

  function abs(n) {
    return Math.abs(n);
  }

  function clamp(n, min, max) {
    return Math.min(Math.max(n, min), max);
  }

  function roundTo(n, decimals) {
    var factor = Math.pow(10, decimals);
    return Math.round(n * factor) / factor;
  }

  function average(values) {
    if (values.length === 0) return 0;
    var sum = values.reduce(function(acc, v) { return acc + v; }, 0);
    return sum / values.length;
  }
  '''
end

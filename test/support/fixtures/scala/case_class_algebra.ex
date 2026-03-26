defmodule Test.Fixtures.Scala.CaseClassAlgebra do
  @moduledoc false
  use Test.LanguageFixture, language: "scala case_class_algebra"

  @code ~S'''
  trait Expr

  class Num(val value: Double) extends Expr

  class Add(val left: Expr, val right: Expr) extends Expr

  class Sub(val left: Expr, val right: Expr) extends Expr

  class Mul(val left: Expr, val right: Expr) extends Expr

  class Div(val left: Expr, val right: Expr) extends Expr

  class Neg(val expr: Expr) extends Expr

  trait EvalResult

  class EvalOk(val value: Double) extends EvalResult

  class EvalError(val message: String) extends EvalResult

  trait Evaluator {
  def eval(expr: Expr): EvalResult
  }

  class SafeEvaluator extends Evaluator {
  def eval(expr: Expr): EvalResult = expr match {
    case n: Num => new EvalOk(n.value)
    case neg: Neg => eval(neg.expr) match {
      case ok: EvalOk => new EvalOk(-ok.value)
      case err => err
    }
    case add: Add => combine(add.left, add.right)(_ + _)
    case sub: Sub => combine(sub.left, sub.right)(_ - _)
    case mul: Mul => combine(mul.left, mul.right)(_ * _)
    case div: Div => eval(div.right) match {
      case ok: EvalOk if ok.value == 0.0 => new EvalError("Division by zero")
      case ok: EvalOk => eval(div.left) match {
        case lOk: EvalOk => new EvalOk(lOk.value / ok.value)
        case err => err
      }
      case err => err
    }
  }

  private def combine(l: Expr, r: Expr)(op: (Double, Double) => Double): EvalResult =
    (eval(l), eval(r)) match {
      case (lv: EvalOk, rv: EvalOk) => new EvalOk(op(lv.value, rv.value))
      case (err: EvalError, _) => err
      case (_, err: EvalError) => err
    }
  }

  trait Printer {
  def print(expr: Expr): String
  }

  class InfixPrinter extends Printer {
  def print(expr: Expr): String = expr match {
    case n: Num => n.value.toString
    case neg: Neg => s"-${print(neg.expr)}"
    case add: Add => s"(${print(add.left)} + ${print(add.right)})"
    case sub: Sub => s"(${print(sub.left)} - ${print(sub.right)})"
    case mul: Mul => s"(${print(mul.left)} * ${print(mul.right)})"
    case div: Div => s"(${print(div.left)} / ${print(div.right)})"
  }
  }
  '''
end

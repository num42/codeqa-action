defmodule Test.Fixtures.Scala.TypeclassPattern do
  @moduledoc false
  use Test.LanguageFixture, language: "scala typeclass_pattern"

  @code ~S'''
  trait Show[A] {
  def show(value: A): String
  }

  trait Eq[A] {
  def eqv(a: A, b: A): Boolean

  def neqv(a: A, b: A): Boolean = !eqv(a, b)
  }

  trait Ord[A] extends Eq[A] {
  def compare(a: A, b: A): Int

  def lt(a: A, b: A): Boolean = compare(a, b) < 0

  def lte(a: A, b: A): Boolean = compare(a, b) <= 0

  def gt(a: A, b: A): Boolean = compare(a, b) > 0

  def gte(a: A, b: A): Boolean = compare(a, b) >= 0

  def eqv(a: A, b: A): Boolean = compare(a, b) == 0
  }

  trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
  }

  class Identity[A](val value: A)

  class IdentityInstances {
  val identityFunctor: Functor[Identity] = new Functor[Identity] {
    def map[A, B](fa: Identity[A])(f: A => B): Identity[B] = new Identity(f(fa.value))
  }

  val identityShow: Show[Identity[String]] = new Show[Identity[String]] {
    def show(value: Identity[String]): String = s"Identity(${value.value})"
  }
  }

  class ShowSyntax[A](value: A, ev: Show[A]) {
  def show: String = ev.show(value)
  }

  class OrdSyntax[A](value: A, ev: Ord[A]) {
  def <(other: A): Boolean = ev.lt(value, other)

  def >(other: A): Boolean = ev.gt(value, other)

  def ===(other: A): Boolean = ev.eqv(value, other)
  }

  trait Monoid[A] {
  def empty: A

  def combine(a: A, b: A): A
  }
  '''
end

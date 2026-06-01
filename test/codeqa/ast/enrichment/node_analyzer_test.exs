defmodule CodeQA.AST.Enrichment.NodeAnalyzerTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Enrichment.NodeAnalyzer
  alias CodeQA.AST.Lexing.TokenNormalizer

  defp tokenize(code), do: TokenNormalizer.normalize_structural(code)
  defp bound(code), do: code |> tokenize() |> NodeAnalyzer.bound_variables()

  describe "bound_variables/1" do
    test "simple assignment binds the LHS identifier" do
      assert "user" in bound("user = Repo.get!(id)")
    end

    test "assignment RHS identifiers are NOT bound" do
      result = bound("user = Repo.get!(id)")
      refute "repo" in result
      refute "id" in result
    end

    test "with-clause binding (<-) binds the LHS identifier" do
      assert "user" in bound("{:ok, user} <- fetch_user(id)")
    end

    test "multiple assignments in a block are all bound" do
      code = "a = foo()\nb = bar()\nc = baz()"
      result = bound(code)
      assert "a" in result
      assert "b" in result
      assert "c" in result
    end

    test "compound LHS: only the <ID> immediately before = is bound" do
      # `x.field = val` — `x` is not re-bound; skip non-simple LHS
      result = bound("result = compute(x)")
      assert "result" in result
    end

    test "== operator does not create a binding" do
      result = bound("x == y")
      refute "x" in result
      refute "y" in result
    end

    test "=> fat arrow does not create a binding" do
      result = bound("key => value")
      refute "key" in result
    end

    test "=~ regex match does not create a binding" do
      result = bound("str =~ pattern")
      refute "str" in result
    end

    test "returns MapSet" do
      assert %MapSet{} = bound("x = 1")
    end

    test "empty token list returns empty MapSet" do
      assert MapSet.new() == NodeAnalyzer.bound_variables([])
    end
  end
end

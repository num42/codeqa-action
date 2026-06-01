defmodule CodeQA.AST.Signals.Structural.SQLBlockSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Structural.SQLBlockSignal
  alias CodeQA.Languages.Data.Sql

  defp split_values(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%SQLBlockSignal{}], Sql)
    for {_src, :split, :sql_block_split, v} <- emissions, do: v
  end

  test "no split for the first statement (seen_content == false)" do
    assert split_values("CREATE TABLE users (id INT);\n") == []
  end

  test "emits split at second CREATE TABLE DDL statement" do
    code = "CREATE TABLE users (id INT);\nCREATE TABLE orders (id INT);\n"
    splits = split_values(code)
    assert length(splits) == 1
  end

  test "emits split at SELECT when a query follows other content" do
    code = "CREATE TABLE users (id INT);\nSELECT id FROM users;\n"
    splits = split_values(code)
    assert length(splits) == 1
  end

  test "emits split at lowercase create (case-insensitive match)" do
    code = "create table users (id INT);\ncreate table orders (id INT);\n"
    splits = split_values(code)
    assert length(splits) == 1
  end

  test "emits split at INSERT after prior content" do
    code = "CREATE TABLE users (id INT);\nINSERT INTO users VALUES (1);\n"
    splits = split_values(code)
    assert length(splits) == 1
  end

  test "does NOT emit for SQL keyword mid-statement (not at line start)" do
    # FROM is not at line start; only SELECT is, but it's the first statement
    code = "SELECT id FROM users;\n"
    splits = split_values(code)
    assert splits == []
  end

  test "does NOT emit for non-SQL identifier at line start" do
    code = "CREATE TABLE users (id INT);\nusername VARCHAR(255);\n"
    splits = split_values(code)
    assert splits == []
  end

  test "group/1 returns :split" do
    assert Signal.group(%SQLBlockSignal{}) == :split
  end
end

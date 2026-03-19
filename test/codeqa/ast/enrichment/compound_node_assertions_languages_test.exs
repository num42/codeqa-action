defmodule CodeQA.AST.Enrichment.CompoundNodeAssertionsLanguagesTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Languages.Unknown
  alias CodeQA.AST.Classification.NodeTypeDetector
  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Enrichment.CompoundNodeBuilder
  alias CodeQA.AST.Enrichment.CompoundNode
  alias CodeQA.AST.Enrichment.Node

  Module.register_attribute(__MODULE__, :fixture, accumulate: true, persist: false)

  # Elixir fixtures
  use Test.Fixtures.Elixir.Calculator
  use Test.Fixtures.Elixir.EventBus
  use Test.Fixtures.Elixir.RateLimiter

  # Python fixtures
  use Test.Fixtures.Python.Calculator
  use Test.Fixtures.Python.CsvPipeline
  use Test.Fixtures.Python.ConfigParser

  # JavaScript fixtures
  use Test.Fixtures.JavaScript.Calculator
  use Test.Fixtures.JavaScript.FormValidator
  use Test.Fixtures.JavaScript.ShoppingCart

  # Go fixtures
  use Test.Fixtures.Go.Calculator
  use Test.Fixtures.Go.HttpMiddleware
  use Test.Fixtures.Go.CliParser

  # Rust fixtures
  use Test.Fixtures.Rust.Calculator
  use Test.Fixtures.Rust.Tokenizer
  use Test.Fixtures.Rust.RingBuffer

  # Ruby fixtures
  use Test.Fixtures.Ruby.Calculator
  use Test.Fixtures.Ruby.OrmLite
  use Test.Fixtures.Ruby.MarkdownRenderer

  # TypeScript fixtures
  use Test.Fixtures.TypeScript.UserProfileStore
  use Test.Fixtures.TypeScript.EventEmitter
  use Test.Fixtures.TypeScript.DependencyInjection

  # Java fixtures
  use Test.Fixtures.Java.BuilderPattern
  use Test.Fixtures.Java.RepositoryPattern
  use Test.Fixtures.Java.StrategyPattern

  # C# fixtures
  use Test.Fixtures.CSharp.LinqPipeline
  use Test.Fixtures.CSharp.AsyncTaskManager
  use Test.Fixtures.CSharp.PluginSystem

  # Swift fixtures
  use Test.Fixtures.Swift.ResultType
  use Test.Fixtures.Swift.CombineStream
  use Test.Fixtures.Swift.ActorModel

  # Kotlin fixtures
  use Test.Fixtures.Kotlin.SealedState
  use Test.Fixtures.Kotlin.CoroutineFlow
  use Test.Fixtures.Kotlin.ExtensionLibrary

  # C++ fixtures
  use Test.Fixtures.Cpp.SmartPointer
  use Test.Fixtures.Cpp.TemplateContainer
  use Test.Fixtures.Cpp.ObserverPattern

  # Scala fixtures
  use Test.Fixtures.Scala.CaseClassAlgebra
  use Test.Fixtures.Scala.TypeclassPattern
  use Test.Fixtures.Scala.ActorMessages

  # Dart fixtures
  use Test.Fixtures.Dart.WidgetState
  use Test.Fixtures.Dart.FuturesAsync
  use Test.Fixtures.Dart.MixinComposition

  # Zig fixtures
  use Test.Fixtures.Zig.AllocatorInterface
  use Test.Fixtures.Zig.TaggedUnion
  use Test.Fixtures.Zig.IteratorProtocol

  # Lua fixtures
  use Test.Fixtures.Lua.ClassSystem
  use Test.Fixtures.Lua.EventSystem
  use Test.Fixtures.Lua.StateMachine

  # Generate tests for fixtures with block_assertions
  for {language, code, block_assertions} <- @fixture, block_assertion <- block_assertions do
    test "[#{language}] #{block_assertion.description}" do
      compounds = compound_nodes(unquote(code))
      none_of = Map.get(unquote(Macro.escape(block_assertion)), :none_of, [])
      all_of = unquote(Macro.escape(block_assertion)).all_of

      assert Enum.any?(compounds, fn compound ->
               tokens = all_tokens(compound)
               compound_satisfies?(tokens, all_of, none_of)
             end),
             "No compound node found matching: #{unquote(block_assertion.description)}"
    end
  end

  defp compound_nodes(code) do
    code
    |> TokenNormalizer.normalize_structural()
    |> Parser.detect_blocks(Unknown)
    |> NodeTypeDetector.detect_types(Unknown)
    |> CompoundNodeBuilder.build()
  end

  defp all_tokens(%CompoundNode{docs: docs, typespecs: typespecs, code: code}) do
    (docs ++ typespecs ++ code)
    |> Enum.flat_map(&node_tokens/1)
  end

  defp node_tokens(node) do
    NodeProtocol.tokens(node)
  end

  defp matches?({:exact, field, value}, token), do: Map.get(token, field) == value

  defp matches?({:partial, field, value}, token),
    do: String.contains?(Map.get(token, field, ""), value)

  defp compound_satisfies?(tokens, all_of, none_of) do
    Enum.all?(all_of, fn matcher -> Enum.any?(tokens, &matches?(matcher, &1)) end) and
      Enum.all?(none_of, fn matcher -> not Enum.any?(tokens, &matches?(matcher, &1)) end)
  end
end

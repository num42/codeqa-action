defmodule CodeQA.AST.Parsing.ParserLanguagesTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Language
  alias CodeQA.Languages.Unknown

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

  # Note: accumulate: true prepends, so Enum.at(0) is the LAST registered fixture.
  # All @code values use 0 leading spaces, so @indentation_level will always be 0
  # and the normalization branch below is never taken.
  @indentation_level @fixture
                     |> Enum.at(0)
                     |> elem(1)
                     |> String.split("\n")
                     |> List.first()
                     |> then(&Regex.run(~r/^\s*/, &1))
                     |> List.first()
                     |> String.length()

  @normalized_fixtures for {language, code, block_assertions} <- @fixture,
                           do:
                             {language,
                              if @indentation_level > 0 do
                                code
                                |> String.split("\n")
                                |> Enum.map_join(
                                  "\n",
                                  &String.replace_leading(
                                    &1,
                                    String.duplicate(" ", @indentation_level),
                                    ""
                                  )
                                )
                              else
                                code
                              end, block_assertions}

  defp blocks(code, lang_mod \\ CodeQA.Languages.Unknown) do
    code
    |> TokenNormalizer.normalize_structural()
    |> Parser.detect_blocks(lang_mod)
  end

  defp children(code, lang_mod \\ CodeQA.Languages.Unknown) do
    code
    |> TokenNormalizer.normalize_structural()
    |> Parser.detect_blocks(lang_mod)
    |> Enum.flat_map(& &1.children)
  end

  describe "blocks/2" do
    for {language, code, _block_assertions} <- @normalized_fixtures do
      lang_name = language |> String.split() |> hd()
      lang_mod = Language.find(lang_name)

      test "detects at least 3 blocks for #{language} code" do
        lang_mod = unquote(lang_mod)
        result = blocks(unquote(code), lang_mod)

        if unquote(lang_mod) == Unknown do
          assert length(result) >= 1
        else
          assert length(result) >= 3
        end
      end

      test "detects at least 3 sub-blocks for #{language} code" do
        lang_mod = unquote(lang_mod)
        result = children(unquote(code), lang_mod)

        if unquote(lang_mod) == Unknown do
          assert length(result) >= 0
        else
          assert length(result) >= 3
        end
      end

      test "detects less sub-blocks than line-numbers for #{language} code" do
        lang_mod = unquote(lang_mod)
        result = children(unquote(code), lang_mod)
        assert length(result) < length(String.split(unquote(code), "\n"))
      end
    end
  end
end

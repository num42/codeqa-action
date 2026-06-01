defmodule Test.LanguageFixture do
  @moduledoc """
  Macro for defining per-language, per-domain code fixtures.

  ## In a fixture module

      defmodule Test.Fixtures.Elixir.EventBus do
        use Test.LanguageFixture, language: "elixir event bus"

        @code ~S'''
        defmodule EventBus do
          ...
        end
        '''
      end

  ## In a test module

      defmodule MyTest do
        Module.register_attribute(__MODULE__, :fixture, accumulate: true, persist: false)
        use Test.Fixtures.Elixir.EventBus
        use Test.Fixtures.Python.CsvPipeline
      end
  """

  defmacro __using__(opts) do
    language = Keyword.fetch!(opts, :language)

    quote do
      @language unquote(language)
      @before_compile Test.LanguageFixture
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    code = Module.get_attribute(mod, :code)
    language = Module.get_attribute(mod, :language)
    block_assertions = Module.get_attribute(mod, :block_assertions) || []

    unless code do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "#{mod} uses Test.LanguageFixture but @code is not set"
    end

    quote do
      defmacro __using__(_opts) do
        fixture_language = unquote(language)
        fixture_code = unquote(code)
        fixture_block_assertions = unquote(Macro.escape(block_assertions))

        quote do
          @fixture {unquote(fixture_language), unquote(fixture_code),
                    unquote(Macro.escape(fixture_block_assertions))}
        end
      end
    end
  end
end

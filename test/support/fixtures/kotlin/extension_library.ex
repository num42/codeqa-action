defmodule Test.Fixtures.Kotlin.ExtensionLibrary do
  @moduledoc false
  use Test.LanguageFixture, language: "kotlin extension_library"

  @code ~S'''
  interface StringValidator {
    fun validate(value: String): Boolean
    fun errorMessage(): String
  }

  interface Transformer<T, R> {
    fun transform(value: T): R
  }

  interface Pipeline<T> {
    fun pipe(step: Transformer<T, T>): Pipeline<T>
    fun execute(input: T): T
  }

  class EmailValidator : StringValidator {
    override fun validate(value: String): Boolean = value.contains("@") && value.contains(".")

    override fun errorMessage(): String = "Invalid email format"
  }

  class LengthValidator(private val min: Int, private val max: Int) : StringValidator {
    override fun validate(value: String): Boolean = value.length in min..max

    override fun errorMessage(): String = "Length must be between $min and $max"
  }

  class TrimTransformer : Transformer<String, String> {
    override fun transform(value: String): String = value.trim()
  }

  class LowercaseTransformer : Transformer<String, String> {
    override fun transform(value: String): String = value.lowercase()
  }

  class StringPipeline : Pipeline<String> {
    private val steps: MutableList<Transformer<String, String>> = mutableListOf()

    override fun pipe(step: Transformer<String, String>): Pipeline<String> {
      steps.add(step)
      return this
    }

    override fun execute(input: String): String = steps.fold(input) { acc, step -> step.transform(acc) }
  }

  enum class ValidationMode {
    STRICT, LENIENT, DISABLED
  }
  '''
end

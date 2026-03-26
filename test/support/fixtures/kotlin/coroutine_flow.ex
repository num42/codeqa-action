defmodule Test.Fixtures.Kotlin.CoroutineFlow do
  @moduledoc false
  use Test.LanguageFixture, language: "kotlin coroutine_flow"

  @code ~S'''
  interface FlowCollector<T> {
    suspend fun emit(value: T)
  }

  interface Flow<T> {
    suspend fun collect(collector: FlowCollector<T>)
  }

  interface Channel<T> {
    suspend fun send(value: T)
    suspend fun receive(): T
    fun close()
    val isClosedForSend: Boolean
  }

  class SimpleFlow<T>(private val block: suspend FlowCollector<T>.() -> Unit) : Flow<T> {
    override suspend fun collect(collector: FlowCollector<T>) {
      collector.block()
    }
  }

  class TransformFlow<T, R>(
    private val upstream: Flow<T>,
    private val transform: suspend (T) -> R
  ) : Flow<R> {
    override suspend fun collect(collector: FlowCollector<R>) {
      upstream.collect(object : FlowCollector<T> {
        override suspend fun emit(value: T) {
          collector.emit(transform(value))
        }
      })
    }
  }

  class FilterFlow<T>(
    private val upstream: Flow<T>,
    private val predicate: suspend (T) -> Boolean
  ) : Flow<T> {
    override suspend fun collect(collector: FlowCollector<T>) {
      upstream.collect(object : FlowCollector<T> {
        override suspend fun emit(value: T) {
          if (predicate(value)) collector.emit(value)
        }
      })
    }
  }

  class BufferedChannel<T>(private val capacity: Int) : Channel<T> {
    private val buffer: ArrayDeque<T> = ArrayDeque()
    override val isClosedForSend: Boolean get() = false

    override suspend fun send(value: T) { buffer.addLast(value) }

    override suspend fun receive(): T = buffer.removeFirst()

    override fun close() { buffer.clear() }
  }
  '''
end

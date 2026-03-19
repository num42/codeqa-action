defmodule Test.Fixtures.Kotlin.SealedState do
  @moduledoc false
  use Test.LanguageFixture, language: "kotlin sealed_state"

  @code ~S'''
  interface Action

  interface State

  interface Reducer<S : State, A : Action> {
    fun reduce(state: S, action: A): S
  }

  class ScreenState {
    class Loading : ScreenState()
    class Success(val data: List<String>) : ScreenState()
    class Error(val message: String, val cause: Throwable?) : ScreenState()
    class Empty : ScreenState()
  }

  class ScreenAction {
    class Load : ScreenAction()
    class LoadSuccess(val data: List<String>) : ScreenAction()
    class LoadError(val message: String, val cause: Throwable?) : ScreenAction()
    class Refresh : ScreenAction()
    class Clear : ScreenAction()
  }

  class ScreenReducer : Reducer<ScreenState, ScreenAction> {
    override fun reduce(state: ScreenState, action: ScreenAction): ScreenState {
      return when (action) {
        is ScreenAction.Load -> ScreenState.Loading()
        is ScreenAction.LoadSuccess -> if (action.data.isEmpty()) ScreenState.Empty() else ScreenState.Success(action.data)
        is ScreenAction.LoadError -> ScreenState.Error(action.message, action.cause)
        is ScreenAction.Refresh -> ScreenState.Loading()
        is ScreenAction.Clear -> ScreenState.Empty()
        else -> state
      }
    }
  }

  enum class LoadStrategy {
    EAGER, LAZY, PREFETCH, BACKGROUND
  }

  class StateStore<S : State, A : Action>(private val reducer: Reducer<S, A>, initialState: S) {
    private var state: S = initialState
    private val listeners: MutableList<(S) -> Unit> = mutableListOf()

    fun getState(): S = state

    fun dispatch(action: A) {
      state = reducer.reduce(state, action)
      listeners.forEach { it(state) }
    }

    fun subscribe(listener: (S) -> Unit): () -> Unit {
      listeners.add(listener)
      return { listeners.remove(listener) }
    }
  }
  '''
end

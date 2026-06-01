defmodule Test.Fixtures.Swift.CombineStream do
  @moduledoc false
  use Test.LanguageFixture, language: "swift combine_stream"

  @code ~S'''
  protocol Publisher {
    associatedtype Output
    associatedtype Failure: Error
    func subscribe(_ subscriber: AnySubscriber<Output, Failure>)
  }

  protocol Subscriber {
    associatedtype Input
    associatedtype Failure: Error
    func receive(_ input: Input)
    func receiveCompletion(_ completion: Completion<Failure>)
  }

  enum Completion<Failure: Error> {
    case finished
    case failure(Failure)
  }

  struct AnySubscriber<Input, Failure: Error> {
    private let receiveValue: (Input) -> Void
    private let receiveCompletion: (Completion<Failure>) -> Void

    init(receiveValue: @escaping (Input) -> Void, receiveCompletion: @escaping (Completion<Failure>) -> Void) {
      self.receiveValue = receiveValue
      self.receiveCompletion = receiveCompletion
    }

    func receive(_ input: Input) { receiveValue(input) }

    func receiveCompletion(_ completion: Completion<Failure>) { self.receiveCompletion(completion) }
  }

  struct Just<Output>: Publisher {
    typealias Failure = Never
    let value: Output

    func subscribe(_ subscriber: AnySubscriber<Output, Never>) {
      subscriber.receive(value)
      subscriber.receiveCompletion(.finished)
    }
  }

  struct MapPublisher<Upstream: Publisher, Output>: Publisher {
    typealias Failure = Upstream.Failure
    let upstream: Upstream
    let transform: (Upstream.Output) -> Output

    func subscribe(_ subscriber: AnySubscriber<Output, Failure>) {
      let mapped = AnySubscriber<Upstream.Output, Failure>(
        receiveValue: { self.upstream.subscribe(AnySubscriber(receiveValue: { _ in }, receiveCompletion: { _ in })); subscriber.receive(self.transform($0)) },
        receiveCompletion: subscriber.receiveCompletion
      )
      upstream.subscribe(mapped)
    }
  }

  func sink<T>(receiveValue: @escaping (T) -> Void) -> AnySubscriber<T, Never> {
    return AnySubscriber(receiveValue: receiveValue, receiveCompletion: { _ in })
  }
  '''
end

defmodule Test.Fixtures.Swift.ResultType do
  @moduledoc false
  use Test.LanguageFixture, language: "swift result_type"

  @code ~S'''
  enum ValidationError: Error {
    case empty(field: String)
    case tooShort(field: String, minimum: Int)
    case tooLong(field: String, maximum: Int)
    case invalidFormat(field: String, pattern: String)
  }

  enum ParseError: Error {
    case invalidJSON
    case missingField(String)
    case typeMismatch(field: String, expected: String)
  }

  struct Email {
    let value: String

    static func parse(_ raw: String) -> Result<Email, ValidationError> {
      guard !raw.isEmpty else { return .failure(.empty(field: "email")) }
      guard raw.contains("@") else { return .failure(.invalidFormat(field: "email", pattern: "must contain @")) }
      return .success(Email(value: raw.lowercased()))
    }
  }

  struct Username {
    let value: String

    static func parse(_ raw: String) -> Result<Username, ValidationError> {
      guard !raw.isEmpty else { return .failure(.empty(field: "username")) }
      guard raw.count >= 3 else { return .failure(.tooShort(field: "username", minimum: 3)) }
      guard raw.count <= 32 else { return .failure(.tooLong(field: "username", maximum: 32)) }
      return .success(Username(value: raw))
    }
  }

  struct UserRegistration {
    let email: Email
    let username: Username

    static func validate(email rawEmail: String, username rawUsername: String) -> Result<UserRegistration, ValidationError> {
      switch Email.parse(rawEmail) {
      case .failure(let e): return .failure(e)
      case .success(let email):
        switch Username.parse(rawUsername) {
        case .failure(let e): return .failure(e)
        case .success(let username): return .success(UserRegistration(email: email, username: username))
        }
      }
    }
  }

  func mapResult<T, U, E: Error>(_ result: Result<T, E>, _ transform: (T) -> U) -> Result<U, E> {
    switch result {
    case .success(let value): return .success(transform(value))
    case .failure(let error): return .failure(error)
    }
  }
  '''
end

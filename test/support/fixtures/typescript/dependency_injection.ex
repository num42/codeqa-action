defmodule Test.Fixtures.TypeScript.DependencyInjection do
  @moduledoc false
  use Test.LanguageFixture, language: "typescript dependency_injection"

  @code ~S'''
  interface Token<T> {
    readonly name: string;
  }

  interface Provider<T> {
    token: Token<T>;
    factory: (container: Container) => T;
    singleton: boolean;
  }

  interface Container {
    register<T>(provider: Provider<T>): void;
    resolve<T>(token: Token<T>): T;
    has<T>(token: Token<T>): boolean;
  }

  class DIContainer implements Container {
    private providers: Map<string, Provider<unknown>>;
    private singletons: Map<string, unknown>;

    constructor() {
      this.providers = new Map();
      this.singletons = new Map();
    }

    register<T>(provider: Provider<T>): void {
      this.providers.set(provider.token.name, provider as Provider<unknown>);
    }

    resolve<T>(token: Token<T>): T {
      const provider = this.providers.get(token.name);
      if (!provider) {
        throw new Error("No provider registered for token: " + token.name);
      }
      if (provider.singleton) {
        if (!this.singletons.has(token.name)) {
          this.singletons.set(token.name, provider.factory(this));
        }
        return this.singletons.get(token.name) as T;
      }
      return provider.factory(this) as T;
    }

    has<T>(token: Token<T>): boolean {
      return this.providers.has(token.name);
    }
  }

  function createToken<T>(name: string): Token<T> {
    return { name };
  }

  function singleton<T>(token: Token<T>, factory: (c: Container) => T): Provider<T> {
    return { token, factory, singleton: true };
  }

  function transient<T>(token: Token<T>, factory: (c: Container) => T): Provider<T> {
    return { token, factory, singleton: false };
  }
  '''
end

defmodule Test.Fixtures.TypeScript.UserProfileStore do
  @moduledoc false
  use Test.LanguageFixture, language: "typescript user_profile_store"

  @code ~S'''
  interface UserProfile {
    id: string;
    name: string;
    email: string;
    role: "admin" | "member" | "guest";
  }

  interface StoreState {
    users: Record<string, UserProfile>;
    loading: boolean;
    error: string | null;
  }

  interface Action {
    type: string;
    payload?: unknown;
  }

  class UserProfileStore {
    private state: StoreState;
    private subscribers: Array<(state: StoreState) => void>;

    constructor() {
      this.state = { users: {}, loading: false, error: null };
      this.subscribers = [];
    }

    getState(): StoreState {
      return this.state;
    }

    dispatch(action: Action): void {
      this.state = this.reduce(this.state, action);
      this.notify();
    }

    subscribe(listener: (state: StoreState) => void): () => void {
      this.subscribers.push(listener);
      return () => {
        this.subscribers = this.subscribers.filter(function(s) { return s !== listener; });
      };
    }

    private reduce(state: StoreState, action: Action): StoreState {
      switch (action.type) {
        case "SET_LOADING":
          return { ...state, loading: action.payload as boolean };
        case "SET_ERROR":
          return { ...state, error: action.payload as string };
        case "UPSERT_USER":
          const user = action.payload as UserProfile;
          return { ...state, users: { ...state.users, [user.id]: user } };
        default:
          return state;
      }
    }

    private notify(): void {
      this.subscribers.forEach(function(listener) { listener(this.state); }.bind(this));
    }
  }

  function createUserProfileStore(): UserProfileStore {
    return new UserProfileStore();
  }
  '''
end

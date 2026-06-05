defmodule MyApp.Search.Result do
  @moduledoc """
  Uniform struct for global search results — GOOD: a pure data definition.

  No debug output of any kind: a struct plus its typespec carries data, it
  does not print. `@type`/`@enforce_keys` blocks are declarations, not logs.
  """

  @enforce_keys [:id, :type, :title, :url]
  defstruct [:id, :type, :title, :subtitle, :url, :distance, meta: %{}]

  @type entity_type :: :position | :item | :asset | :brand | :manufacturer

  @type t :: %__MODULE__{
          distance: float() | nil,
          id: binary(),
          meta: map(),
          subtitle: String.t() | nil,
          title: String.t(),
          type: entity_type(),
          url: String.t()
        }
end

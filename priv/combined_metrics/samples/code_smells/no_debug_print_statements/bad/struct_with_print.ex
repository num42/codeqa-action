defmodule MyApp.Search.Result do
  @moduledoc """
  Search result struct — BAD: a debug print left in the constructor helper.
  """

  @enforce_keys [:id, :type, :title, :url]
  defstruct [:id, :type, :title, :subtitle, :url, :distance, meta: %{}]

  @type t :: %__MODULE__{
          distance: float() | nil,
          id: binary(),
          title: String.t(),
          type: atom(),
          url: String.t()
        }

  def new(attrs) do
    IO.inspect(attrs, label: "Result.new attrs")
    struct!(__MODULE__, attrs)
  end
end

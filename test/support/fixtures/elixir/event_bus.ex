defmodule Test.Fixtures.Elixir.EventBus do
  @moduledoc false
  use Test.LanguageFixture, language: "elixir event_bus"

  @code ~S'''
  defmodule EventBus.Behaviour do
    @moduledoc "Contract for event bus implementations."
    @callback subscribe(topic :: String.t(), pid :: pid()) :: :ok | {:error, term()}
    @callback unsubscribe(topic :: String.t(), pid :: pid()) :: :ok
    @callback publish(topic :: String.t(), event :: term()) :: :ok
    @callback topics() :: [String.t()]
  end

  defprotocol EventBus.Serializable do
    @doc "Encodes an event to a binary payload."
    @spec encode(t()) :: binary()
    def encode(event)

    @doc "Decodes a binary payload back to an event."
    @spec decode(t(), binary()) :: term()
    def decode(schema, payload)
  end

  defmodule EventBus.Topic do
    @moduledoc "Represents a named event topic with subscriber tracking."
    @enforce_keys [:name]
    defstruct [:name, subscribers: []]

    @doc "Creates a new topic."
    @spec new(String.t()) :: t()
    def new(name) when is_binary(name), do: %__MODULE__{name: name}

    @doc "Adds a subscriber pid to the topic."
    @spec add_subscriber(t(), pid()) :: t()
    def add_subscriber(%__MODULE__{subscribers: subs} = topic, pid) do
      %{topic | subscribers: [pid | subs]}
    end

    @doc "Removes a subscriber pid from the topic."
    @spec remove_subscriber(t(), pid()) :: t()
    def remove_subscriber(%__MODULE__{subscribers: subs} = topic, pid) do
      %{topic | subscribers: List.delete(subs, pid)}
    end

    @doc "Returns all current subscribers."
    @spec subscribers(t()) :: [pid()]
    def subscribers(%__MODULE__{subscribers: subs}), do: subs
  end

  defmodule EventBus.Dispatcher do
    @moduledoc "Dispatches events to all topic subscribers."

    @doc "Broadcasts an event to every subscriber of the given topic."
    @spec broadcast(EventBus.Topic.t(), term()) :: :ok
    def broadcast(%EventBus.Topic{} = topic, event) do
      topic
      |> EventBus.Topic.subscribers()
      |> Enum.each(&send(&1, {:event, topic.name, event}))
    end

    @doc "Dispatches to subscribers matching a predicate."
    @spec dispatch_filtered(EventBus.Topic.t(), term(), (pid() -> boolean())) :: :ok
    def dispatch_filtered(%EventBus.Topic{} = topic, event, filter_fn) do
      topic
      |> EventBus.Topic.subscribers()
      |> Enum.filter(filter_fn)
      |> Enum.each(&send(&1, {:event, topic.name, event}))
    end
  end
  '''
end

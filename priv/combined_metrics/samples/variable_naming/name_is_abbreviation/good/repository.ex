defmodule Repository.Good do
  @moduledoc """
  Data-access layer using full, descriptive variable names.
  GOOD: connection, statement, transaction, record — names spell out intent.
  """

  @spec fetch(map(), integer()) :: {:ok, map()} | {:error, term()}
  def fetch(connection, identifier) do
    statement = "SELECT * FROM accounts WHERE id = $1"

    case run(connection, statement, [identifier]) do
      {:ok, [record | _]} -> {:ok, record}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec insert(map(), map()) :: {:ok, map()} | {:error, term()}
  def insert(connection, attributes) do
    statement = "INSERT INTO accounts (email, role) VALUES ($1, $2) RETURNING *"
    parameters = [attributes.email, attributes.role]

    case run(connection, statement, parameters) do
      {:ok, [record | _]} -> {:ok, record}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec transfer(map(), integer(), integer(), integer()) :: {:ok, map()} | {:error, term()}
  def transfer(connection, source, destination, amount) do
    transaction = build_transaction(source, destination, amount)

    case run(connection, transaction.statement, transaction.parameters) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_transaction(source, destination, amount) do
    %{
      statement: "CALL transfer($1, $2, $3)",
      parameters: [source, destination, amount]
    }
  end

  defp run(_connection, _statement, _parameters), do: {:ok, []}
end

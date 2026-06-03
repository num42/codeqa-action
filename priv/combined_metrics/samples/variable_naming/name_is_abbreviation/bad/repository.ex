defmodule Repository.Bad do
  @moduledoc """
  Data-access layer using abbreviated variable names.
  BAD: conn, stmt, txn, rec, attrs, params, src, dst obscure intent.
  """

  @spec fetch(map(), integer()) :: {:ok, map()} | {:error, term()}
  def fetch(conn, id) do
    stmt = "SELECT * FROM accounts WHERE id = $1"

    case run(conn, stmt, [id]) do
      {:ok, [rec | _]} -> {:ok, rec}
      {:ok, []} -> {:error, :not_found}
      {:error, rsn} -> {:error, rsn}
    end
  end

  @spec insert(map(), map()) :: {:ok, map()} | {:error, term()}
  def insert(conn, attrs) do
    stmt = "INSERT INTO accounts (email, role) VALUES ($1, $2) RETURNING *"
    params = [attrs.email, attrs.role]

    case run(conn, stmt, params) do
      {:ok, [rec | _]} -> {:ok, rec}
      {:error, rsn} -> {:error, rsn}
    end
  end

  @spec transfer(map(), integer(), integer(), integer()) :: {:ok, map()} | {:error, term()}
  def transfer(conn, src, dst, amt) do
    txn = build_txn(src, dst, amt)

    case run(conn, txn.stmt, txn.params) do
      {:ok, res} -> {:ok, res}
      {:error, rsn} -> {:error, rsn}
    end
  end

  defp build_txn(src, dst, amt) do
    %{
      stmt: "CALL transfer($1, $2, $3)",
      params: [src, dst, amt]
    }
  end

  defp run(_conn, _stmt, _params), do: {:ok, []}
end

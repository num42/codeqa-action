defmodule MyApp.QueryHelpers do
  @moduledoc """
  Helpers for building common Ecto query patterns.
  """

  import Ecto.Query
  import Ecto.Changeset
  import MyApp.QueryFilters
  import MyApp.PaginationHelpers

  @spec paginate(Ecto.Queryable.t(), map()) :: Ecto.Query.t()
  def paginate(query, params) do
    page = Map.get(params, "page", 1)
    per_page = Map.get(params, "per_page", 20)

    query
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
  end

  @spec filter_by_status(Ecto.Queryable.t(), atom()) :: Ecto.Query.t()
  def filter_by_status(query, status) do
    where(query, [q], q.status == ^status)
  end

  @spec filter_by_user(Ecto.Queryable.t(), integer()) :: Ecto.Query.t()
  def filter_by_user(query, user_id) do
    where(query, [q], q.user_id == ^user_id)
  end

  @spec order_by_inserted(Ecto.Queryable.t(), :asc | :desc) :: Ecto.Query.t()
  def order_by_inserted(query, direction \\ :desc) do
    order_by(query, [q], [{^direction, q.inserted_at}])
  end

  @spec search_name(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def search_name(query, term) do
    like_term = "%#{term}%"
    where(query, [q], ilike(q.name, ^like_term))
  end

  @spec with_preloads(Ecto.Queryable.t(), list()) :: Ecto.Query.t()
  def with_preloads(query, associations) do
    preload(query, ^associations)
  end

  @spec apply_filters(Ecto.Queryable.t(), map()) :: Ecto.Query.t()
  def apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {"status", status}, q -> filter_by_status(q, String.to_atom(status))
      {"user_id", id}, q -> filter_by_user(q, id)
      {"search", term}, q -> search_name(q, term)
      _unknown, q -> q
    end)
  end

  @spec validate_and_apply(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_and_apply(changeset, attrs) do
    changeset
    |> cast(attrs, [:status, :name])
    |> validate_required([:status])
    |> validate_inclusion(:status, [:active, :inactive, :pending])
  end

  @spec count_query(Ecto.Queryable.t()) :: Ecto.Query.t()
  def count_query(query) do
    from q in query, select: count(q.id)
  end

  @spec date_range(Ecto.Queryable.t(), Date.t(), Date.t()) :: Ecto.Query.t()
  def date_range(query, from_date, to_date) do
    where(query, [q], q.inserted_at >= ^from_date and q.inserted_at <= ^to_date)
  end
end

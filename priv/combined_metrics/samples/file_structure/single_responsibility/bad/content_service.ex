defmodule ContentService do
  @moduledoc """
  Handles all content concerns: slugs, persistence, search indexing,
  cache invalidation, and webhook notifications.
  """

  require Logger

  def publish(article) do
    slug = generate_slug(article.title)
    record = Map.put(article, :slug, slug)
    persist(record)
    index_for_search(record)
    invalidate_cache(record.slug)
    notify_webhooks(:published, record)
    log_audit(:article_published, record)
    {:ok, record}
  end

  def generate_slug(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  def persist(record) do
    statement = "INSERT INTO articles (slug, title, body) VALUES ($1, $2, $3)"
    execute(statement, [record.slug, record.title, record.body])
    Logger.info("Persisted article #{record.slug}")
    :ok
  end

  def index_for_search(record) do
    document = %{id: record.slug, title: record.title, content: strip_html(record.body)}
    push_to_search_engine(document)
    :ok
  end

  def invalidate_cache(slug) do
    cache_delete("article:#{slug}")
    cache_delete("article_list")
    :ok
  end

  def notify_webhooks(event, record) do
    payload = %{event: event, slug: record.slug, at: DateTime.utc_now()}

    Enum.each(registered_hooks(), fn url ->
      post_webhook(url, payload)
    end)
  end

  defp strip_html(body), do: String.replace(body, ~r/<[^>]*>/, "")
  defp execute(_statement, _params), do: :ok
  defp push_to_search_engine(_document), do: :ok
  defp cache_delete(_key), do: :ok
  defp registered_hooks, do: []
  defp post_webhook(_url, _payload), do: :ok
  defp log_audit(event, record), do: Logger.info("AUDIT: #{event} #{record.slug}")
end

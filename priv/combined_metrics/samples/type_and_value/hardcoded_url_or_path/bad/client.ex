defmodule Http.Client do
  @moduledoc """
  HTTP API client — BAD: URLs and paths are hardcoded throughout function bodies.
  """

  def fetch_user(id) do
    url = "https://api.example.com/v1/users/#{id}"
    get(url)
  end

  def create_order(params) do
    url = "https://api.example.com/v1/orders"
    post(url, params)
  end

  def upload_file(content, filename) do
    path = "/tmp/uploads/#{filename}"
    File.write!(path, content)
    url = "https://api.example.com/v1/files"
    post(url, %{path: path})
  end

  def fetch_product_catalog do
    url = "https://api.example.com/v1/products?page=1&per_page=100"
    get(url)
  end

  def send_webhook(event) do
    url = "https://hooks.example.com/incoming/abc123xyz"
    post(url, event)
  end

  def download_report(report_id) do
    url = "https://reports.example.com/api/v2/reports/#{report_id}/export"
    dest = "/var/app/downloads/report_#{report_id}.pdf"
    content = get(url)
    File.write!(dest, content)
    dest
  end

  def fetch_exchange_rates do
    url = "https://api.exchangerate.host/latest?base=USD"
    get(url)
  end

  def post_to_slack(message) do
    url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXX"
    post(url, %{text: message})
  end

  defp get(url), do: {:ok, %{url: url, body: ""}}
  defp post(url, body), do: {:ok, %{url: url, body: body}}
end

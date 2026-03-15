defmodule Http.Client do
  @moduledoc """
  HTTP API client — GOOD: URLs and paths are defined as module attributes or fetched from config.
  """

  @api_base Application.compile_env(:my_app, :api_base_url, "https://api.example.com/v1")
  @webhook_url Application.compile_env(:my_app, :webhook_url, "https://hooks.example.com/incoming")
  @reports_base Application.compile_env(:my_app, :reports_base_url, "https://reports.example.com/api/v2")

  defp upload_dir, do: Application.get_env(:my_app, :upload_dir, "/tmp/uploads")
  defp download_dir, do: Application.get_env(:my_app, :download_dir, "/var/app/downloads")
  defp slack_webhook_url, do: Application.fetch_env!(:my_app, :slack_webhook_url)
  defp exchange_rates_url, do: Application.get_env(:my_app, :exchange_rates_url, "https://api.exchangerate.host/latest")

  def fetch_user(id) do
    get("#{@api_base}/users/#{id}")
  end

  def create_order(params) do
    post("#{@api_base}/orders", params)
  end

  def upload_file(content, filename) do
    path = Path.join(upload_dir(), filename)
    File.write!(path, content)
    post("#{@api_base}/files", %{path: path})
  end

  def fetch_product_catalog do
    get("#{@api_base}/products?page=1&per_page=100")
  end

  def send_webhook(event) do
    post(@webhook_url, event)
  end

  def download_report(report_id) do
    url = "#{@reports_base}/reports/#{report_id}/export"
    dest = Path.join(download_dir(), "report_#{report_id}.pdf")
    content = get(url)
    File.write!(dest, content)
    dest
  end

  def fetch_exchange_rates do
    get("#{exchange_rates_url()}?base=USD")
  end

  def post_to_slack(message) do
    post(slack_webhook_url(), %{text: message})
  end

  defp get(url), do: {:ok, %{url: url, body: ""}}
  defp post(url, body), do: {:ok, %{url: url, body: body}}
end

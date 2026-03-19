# Application config and HTTP client using correctly-cased module constants.
# GOOD: module-level constants use SCREAMING_SNAKE_CASE to distinguish them from variables.

require 'net/http'
require 'json'
require 'uri'

class ConfigGood
  MAX_RETRIES = 3
  DEFAULT_TIMEOUT = 5
  API_BASE_URL = 'https://api.example.com/v1'
  PAGE_SIZE = 25
  RETRY_DELAY = 1
  MAX_PAGE_SIZE = 100
  CONNECT_TIMEOUT = 2
  DEFAULT_HEADERS = { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }.freeze

  def fetch_data(path)
    url = URI(API_BASE_URL + path)
    request_with_retry(url, MAX_RETRIES, DEFAULT_TIMEOUT)
  end

  def fetch_page(path, page)
    size = [page, MAX_PAGE_SIZE].min
    url = URI("#{API_BASE_URL}#{path}?page=#{page}&size=#{size}")
    request_with_retry(url, MAX_RETRIES, DEFAULT_TIMEOUT)
  end

  def paginate_all(path)
    all_items = []
    page = 1

    loop do
      result = fetch_page(path, page)
      return { ok: false, error: result[:error] } unless result[:ok]

      all_items.concat(result[:data][:items])
      break if result[:data][:items].length < PAGE_SIZE

      page += 1
    end

    { ok: true, data: all_items }
  end

  def post_data(path, body)
    url = URI(API_BASE_URL + path)
    post_with_retry(url, body, MAX_RETRIES)
  end

  private

  def request_with_retry(url, retries_left, timeout)
    http = Net::HTTP.new(url.host, url.port)
    http.read_timeout = timeout
    http.open_timeout = CONNECT_TIMEOUT

    request = Net::HTTP::Get.new(url)
    DEFAULT_HEADERS.each { |k, v| request[k] = v }

    response = http.request(request)

    if response.code.to_i >= 500 && retries_left > 0
      sleep(RETRY_DELAY)
      return request_with_retry(url, retries_left - 1, timeout)
    end

    return { ok: false, error: "HTTP #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

    { ok: true, data: JSON.parse(response.body, symbolize_names: true) }
  rescue => error
    if retries_left > 0
      sleep(RETRY_DELAY)
      request_with_retry(url, retries_left - 1, timeout)
    else
      { ok: false, error: error.message }
    end
  end

  def post_with_retry(url, body, retries_left)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url)
    DEFAULT_HEADERS.each { |k, v| request[k] = v }
    request.body = body.to_json

    response = http.request(request)

    return { ok: true, data: JSON.parse(response.body, symbolize_names: true) } if %w[200 201].include?(response.code)

    if retries_left > 0
      sleep(RETRY_DELAY)
      return post_with_retry(url, body, retries_left - 1)
    end

    { ok: false, error: "HTTP #{response.code}" }
  rescue => error
    { ok: false, error: error.message }
  end
end

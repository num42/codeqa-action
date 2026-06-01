# Application config and HTTP client using incorrectly-cased module constants.
# BAD: module-level constants use camelCase or lowercase instead of SCREAMING_SNAKE_CASE.

require 'net/http'
require 'json'
require 'uri'

class ConfigBad
  maxRetries = 3
  defaultTimeout = 5
  apiBaseUrl = 'https://api.example.com/v1'
  pageSize = 25
  retryDelay = 1
  maxPageSize = 100
  connectTimeout = 2

  MaxRetries = maxRetries
  DefaultTimeout = defaultTimeout
  ApiBaseUrl = apiBaseUrl
  PageSize = pageSize
  RetryDelay = retryDelay
  MaxPageSize = maxPageSize
  ConnectTimeout = connectTimeout
  DefaultHeaders = { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }.freeze

  def fetch_data(path)
    url = URI(ApiBaseUrl + path)
    request_with_retry(url, MaxRetries, DefaultTimeout)
  end

  def fetch_page(path, page)
    size = [page, MaxPageSize].min
    url = URI("#{ApiBaseUrl}#{path}?page=#{page}&size=#{size}")
    request_with_retry(url, MaxRetries, DefaultTimeout)
  end

  def paginate_all(path)
    all_items = []
    page = 1

    loop do
      result = fetch_page(path, page)
      return { ok: false, error: result[:error] } unless result[:ok]

      all_items.concat(result[:data][:items])
      break if result[:data][:items].length < PageSize

      page += 1
    end

    { ok: true, data: all_items }
  end

  def post_data(path, body)
    url = URI(ApiBaseUrl + path)
    post_with_retry(url, body, MaxRetries)
  end

  private

  def request_with_retry(url, retries_left, timeout)
    http = Net::HTTP.new(url.host, url.port)
    http.read_timeout = timeout
    http.open_timeout = ConnectTimeout

    request = Net::HTTP::Get.new(url)
    DefaultHeaders.each { |k, v| request[k] = v }

    response = http.request(request)

    if response.code.to_i >= 500 && retries_left > 0
      sleep(RetryDelay)
      return request_with_retry(url, retries_left - 1, timeout)
    end

    return { ok: false, error: "HTTP #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

    { ok: true, data: JSON.parse(response.body, symbolize_names: true) }
  rescue => error
    if retries_left > 0
      sleep(RetryDelay)
      request_with_retry(url, retries_left - 1, timeout)
    else
      { ok: false, error: error.message }
    end
  end

  def post_with_retry(url, body, retries_left)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url)
    DefaultHeaders.each { |k, v| request[k] = v }
    request.body = body.to_json

    response = http.request(request)

    return { ok: true, data: JSON.parse(response.body, symbolize_names: true) } if %w[200 201].include?(response.code)

    if retries_left > 0
      sleep(RetryDelay)
      return post_with_retry(url, body, retries_left - 1)
    end

    { ok: false, error: "HTTP #{response.code}" }
  rescue => error
    { ok: false, error: error.message }
  end
end

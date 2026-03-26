# HTTP API client using descriptive variable names.
# GOOD: variables like user, config, request, response, address, message are clear.

require 'net/http'
require 'json'
require 'uri'

class ApiClientGood
  def send_request(config, user)
    request_data = build_request(config, user)
    address = URI("#{config[:base_url]}#{request_data[:path]}")

    response = Net::HTTP.post(address, request_data[:body], request_data[:headers])
    message = JSON.parse(response.body)

    { ok: response.is_a?(Net::HTTPSuccess), data: message }
  rescue => error
    { ok: false, error: "Request failed: #{error.message}" }
  end

  def fetch_product(config, product_id)
    address = URI("#{config[:base_url]}/products/#{product_id}")
    request = Net::HTTP::Get.new(address)
    request['Authorization'] = "Bearer #{config[:api_key]}"

    response = Net::HTTP.start(address.host, address.port) { |http| http.request(request) }

    unless response.is_a?(Net::HTTPSuccess)
      message = "Unexpected status: #{response.code}"
      return { ok: false, error: message }
    end

    product = JSON.parse(response.body)
    { ok: true, data: product }
  rescue => error
    { ok: false, error: error.message }
  end

  def create_order(config, user, quantity)
    address = URI("#{config[:base_url]}/orders")
    request = Net::HTTP::Post.new(address)
    request['Authorization'] = "Bearer #{config[:api_key]}"
    request['Content-Type'] = 'application/json'
    request.body = JSON.dump({ user_id: user[:id], quantity: quantity })

    response = Net::HTTP.start(address.host, address.port) { |http| http.request(request) }
    message = JSON.parse(response.body)

    return { ok: false, error: extract_error_message(message) } unless response.is_a?(Net::HTTPSuccess)

    { ok: true, data: message }
  rescue => error
    { ok: false, error: error.message }
  end

  def paginate(config, params)
    query_string = URI.encode_www_form(params)
    address = URI("#{config[:base_url]}/items?#{query_string}")
    request = Net::HTTP::Get.new(address)
    request['Authorization'] = "Bearer #{config[:api_key]}"

    response = Net::HTTP.start(address.host, address.port) { |http| http.request(request) }
    data = JSON.parse(response.body)

    { ok: response.is_a?(Net::HTTPSuccess), data: data }
  rescue => error
    { ok: false, error: error.message }
  end

  def upload_file(config, user, buffer)
    address = URI("#{config[:base_url]}/uploads")
    request = Net::HTTP::Post.new(address)
    request['Authorization'] = "Bearer #{config[:api_key]}"
    request.body = buffer
    request['X-User-Id'] = user[:id].to_s

    response = Net::HTTP.start(address.host, address.port) { |http| http.request(request) }
    message = JSON.parse(response.body)

    { ok: response.is_a?(Net::HTTPSuccess), data: message }
  end

  private

  def build_request(config, user)
    { path: '/requests', body: JSON.dump({ user_id: user[:id] }), headers: auth_headers(config) }
  end

  def auth_headers(config) = { 'Authorization' => "Bearer #{config[:api_key]}" }
  def extract_error_message(message) = message['error'] || 'Unknown error'
end

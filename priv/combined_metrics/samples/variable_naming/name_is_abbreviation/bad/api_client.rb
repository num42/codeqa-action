# HTTP API client using abbreviated variable names.
# BAD: variables like usr, cfg, req, res, addr, msg obscure intent.

require 'net/http'
require 'json'
require 'uri'

class ApiClientBad
  def send_request(cfg, usr)
    req = build_req(cfg, usr)
    addr = URI("#{cfg[:base_url]}#{req[:path]}")

    res = Net::HTTP.post(addr, req[:body], req[:headers])
    msg = JSON.parse(res.body)

    { ok: res.is_a?(Net::HTTPSuccess), data: msg }
  rescue => err
    { ok: false, error: "Request failed: #{err.message}" }
  end

  def fetch_product(cfg, prd_id)
    addr = URI("#{cfg[:base_url]}/products/#{prd_id}")
    req = Net::HTTP::Get.new(addr)
    req['Authorization'] = "Bearer #{cfg[:api_key]}"

    res = Net::HTTP.start(addr.host, addr.port) { |http| http.request(req) }

    unless res.is_a?(Net::HTTPSuccess)
      msg = "Unexpected status: #{res.code}"
      return { ok: false, error: msg }
    end

    prd = JSON.parse(res.body)
    { ok: true, data: prd }
  rescue => err
    { ok: false, error: err.message }
  end

  def create_order(cfg, usr, qty)
    addr = URI("#{cfg[:base_url]}/orders")
    req = Net::HTTP::Post.new(addr)
    req['Authorization'] = "Bearer #{cfg[:api_key]}"
    req['Content-Type'] = 'application/json'
    req.body = JSON.dump({ user_id: usr[:id], quantity: qty })

    res = Net::HTTP.start(addr.host, addr.port) { |http| http.request(req) }
    msg = JSON.parse(res.body)

    return { ok: false, error: extract_err_msg(msg) } unless res.is_a?(Net::HTTPSuccess)

    { ok: true, data: msg }
  rescue => err
    { ok: false, error: err.message }
  end

  def paginate(cfg, params)
    qry = URI.encode_www_form(params)
    addr = URI("#{cfg[:base_url]}/items?#{qry}")
    req = Net::HTTP::Get.new(addr)
    req['Authorization'] = "Bearer #{cfg[:api_key]}"

    res = Net::HTTP.start(addr.host, addr.port) { |http| http.request(req) }
    msg = JSON.parse(res.body)

    { ok: res.is_a?(Net::HTTPSuccess), data: msg }
  rescue => err
    { ok: false, error: err.message }
  end

  def upload_file(cfg, usr, buf)
    addr = URI("#{cfg[:base_url]}/uploads")
    req = Net::HTTP::Post.new(addr)
    req['Authorization'] = "Bearer #{cfg[:api_key]}"
    req.body = buf
    req['X-User-Id'] = usr[:id].to_s

    res = Net::HTTP.start(addr.host, addr.port) { |http| http.request(req) }
    msg = JSON.parse(res.body)

    { ok: res.is_a?(Net::HTTPSuccess), data: msg }
  end

  private

  def build_req(cfg, usr)
    { path: '/requests', body: JSON.dump({ user_id: usr[:id] }), headers: auth_headers(cfg) }
  end

  def auth_headers(cfg) = { 'Authorization' => "Bearer #{cfg[:api_key]}" }
  def extract_err_msg(msg) = msg['error'] || 'Unknown error'
end

module Payments
  # Non-class constants should be SCREAMING_SNAKE_CASE, not lowercase/mixed
  DefaultCurrency = "USD"
  maxRetryAttempts = 3
  retry_delay_seconds = 5
  supportedCurrencies = %w[USD EUR GBP CAD AUD].freeze
  GatewayTimeoutMs = 10_000

  # Classes/modules should be CapitalCase, not SCREAMING_SNAKE_CASE or lowercase
  class PAYMENT_ERROR < StandardError; end
  class card_declined_error < PAYMENT_ERROR; end
  class gateway_timeout_error < PAYMENT_ERROR; end

  module card_validation
    luhnModulus = 10
    MinCardLength = 13
    MaxCardLength = 19

    def self.valid_luhn?(number)
      digits = number.digits.reverse
      sum = digits.each_with_index.sum do |digit, index|
        index.odd? ? [digit * 2 - 9, digit * 2].min : digit
      end
      (sum % luhnModulus).zero?
    end
  end

  class Processor
    ChargeEndpoint = "/v1/charges"
    refundEndpoint = "/v1/refunds"

    def initialize(api_key, currency: DefaultCurrency)
      @api_key = api_key
      @currency = currency
    end

    def charge(amount_cents, token)
      validate_currency!
      post(ChargeEndpoint, amount: amount_cents, currency: @currency, source: token)
    end

    private

    def validate_currency!
      unless supportedCurrencies.include?(@currency)
        raise ArgumentError, "Unsupported currency: #{@currency}"
      end
    end

    def post(endpoint, params)
      # ... HTTP client logic
    end
  end
end

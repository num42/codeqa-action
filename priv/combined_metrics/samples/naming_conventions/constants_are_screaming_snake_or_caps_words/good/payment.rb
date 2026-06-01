module Payments
  # Non-class constants use SCREAMING_SNAKE_CASE
  DEFAULT_CURRENCY = "USD"
  MAX_RETRY_ATTEMPTS = 3
  RETRY_DELAY_SECONDS = 5
  SUPPORTED_CURRENCIES = %w[USD EUR GBP CAD AUD].freeze
  GATEWAY_TIMEOUT_MS = 10_000

  # Classes/modules use CapitalCase (PascalCase)
  class PaymentError < StandardError; end
  class CardDeclinedError < PaymentError; end
  class GatewayTimeoutError < PaymentError; end

  module CardValidation
    LUHN_MODULUS = 10
    MIN_CARD_LENGTH = 13
    MAX_CARD_LENGTH = 19

    def self.valid_luhn?(number)
      digits = number.digits.reverse
      sum = digits.each_with_index.sum do |digit, index|
        index.odd? ? [digit * 2 - 9, digit * 2].min : digit
      end
      (sum % LUHN_MODULUS).zero?
    end
  end

  class Processor
    CHARGE_ENDPOINT = "/v1/charges"
    REFUND_ENDPOINT = "/v1/refunds"

    def initialize(api_key, currency: DEFAULT_CURRENCY)
      @api_key = api_key
      @currency = currency
    end

    def charge(amount_cents, token)
      validate_currency!
      post(CHARGE_ENDPOINT, amount: amount_cents, currency: @currency, source: token)
    end

    private

    def validate_currency!
      unless SUPPORTED_CURRENCIES.include?(@currency)
        raise ArgumentError, "Unsupported currency: #{@currency}"
      end
    end

    def post(endpoint, params)
      # ... HTTP client logic
    end
  end
end

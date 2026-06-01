# Data processing pipeline — GOOD: variables declared immediately before use.

require "securerandom"
require "time"

module Pipeline
  module Processor
    module_function

    def process_order(order)
      min_price = 0.01
      max_items = 50

      validated = order[:items].select do |item|
        item[:quantity] > 0 &&
          item[:price] >= min_price &&
          order[:items].length <= max_items
      end

      subtotal = validated.reduce(0) { |acc, item| acc + item[:price] * item[:quantity] }

      discount_threshold = 100
      premium_discount = 0.15
      standard_discount = 0.05

      discount =
        if subtotal > discount_threshold
          subtotal * premium_discount
        else
          subtotal * standard_discount
        end

      discounted = subtotal - discount
      tax_rate = 0.08
      tax = discounted * tax_rate
      total = discounted + tax

      currency = "USD"
      { total: total, currency: currency, item_count: validated.length }
    end

    def process_batch(orders)
      max_batch_size = 200

      return [:batch_error, :too_large] if orders.length > max_batch_size

      results = orders.map do |order|
        outcome = process_order(order)
        outcome[:total] > 0 ? [:ok, outcome[:total]] : [:batch_error, order[:id]]
      end

      successes = results.count { |status, _| status == :ok }
      batch_id = SecureRandom.uuid
      started_at = Time.now.utc

      {
        batch_id: batch_id,
        started_at: started_at,
        total: orders.length,
        successes: successes
      }
    end

    def summarize(results)
      lines = results.map { |status, val| "#{status}: #{val}" }
      body = lines.join("\n")

      label = "Summary"
      separator = "-" * 40

      "#{label}\n#{separator}\n#{body}"
    end
  end
end

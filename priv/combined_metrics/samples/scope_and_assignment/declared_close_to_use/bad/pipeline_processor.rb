# Data processing pipeline — BAD: variables declared far from their use.

require "securerandom"
require "time"

module Pipeline
  module Processor
    module_function

    def process_order(order)
      # All variables declared upfront, used much later
      tax_rate = 0.08
      discount_threshold = 100
      premium_discount = 0.15
      standard_discount = 0.05
      currency = "USD"
      max_items = 50
      min_price = 0.01

      items = order[:items]

      validated = items.select do |item|
        item[:quantity] > 0 &&
          item[:price] >= min_price &&
          items.length <= max_items
      end

      subtotal = validated.reduce(0) { |acc, item| acc + item[:price] * item[:quantity] }

      # discount_threshold, premium_discount, standard_discount declared ~17 lines ago
      discount =
        if subtotal > discount_threshold
          subtotal * premium_discount
        else
          subtotal * standard_discount
        end

      discounted = subtotal - discount

      # tax_rate declared ~25 lines ago
      tax = discounted * tax_rate

      total = discounted + tax

      # currency declared ~28 lines ago
      { total: total, currency: currency, item_count: validated.length }
    end

    def process_batch(orders)
      # Variables declared at top, used at different depths
      batch_id = SecureRandom.uuid
      started_at = Time.now.utc
      max_batch_size = 200
      error_tag = :batch_error

      if orders.length > max_batch_size
        # error_tag used for the first time ~5 lines after declaration
        return [error_tag, :too_large]
      end

      results = orders.map do |order|
        outcome = process_order(order)
        if outcome[:total] > 0
          [:ok, outcome[:total]]
        else
          # error_tag used again here, many lines from declaration
          [error_tag, order[:id]]
        end
      end

      # started_at and batch_id used ~20 lines after declaration
      successes = results.count { |status, _| status == :ok }

      {
        batch_id: batch_id,
        started_at: started_at,
        total: orders.length,
        successes: successes
      }
    end

    def summarize(results)
      label = "Summary"
      separator = "-" * 40
      format = :detailed

      lines = results.map { |status, val| "#{status}: #{val}" }
      body = lines.join("\n")

      # label, separator, format all declared ~7 lines ago
      if format == :detailed
        "#{label}\n#{separator}\n#{body}"
      else
        "#{label}: #{lines.length} results"
      end
    end
  end
end

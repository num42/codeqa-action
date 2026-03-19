class ShoppingCart
  attr_reader :lineItems, :customerId, :couponCode

  def initialize(customerId)
    @customerId = customerId
    @lineItems = []
    @couponCode = nil
  end

  # camelCase method names violate Ruby convention
  def addItem(productId, quantity = 1, unitPrice:)
    existing = findLineItem(productId)

    if existing
      existing.incrementQuantity(quantity)
    else
      @lineItems << LineItem.new(productId: productId, quantity: quantity, unitPrice: unitPrice)
    end

    self
  end

  def removeItem(productId)
    @lineItems.reject! { |item| item.productId == productId }
    self
  end

  def applyCouponCode(code)
    @couponCode = code
    self
  end

  def calculateSubtotal
    lineItems.sum(&:lineTotal)
  end

  def calculateTax(rate:)
    calculateSubtotal * rate
  end

  def totalItemCount
    lineItems.sum(&:quantity)
  end

  def isEmpty
    lineItems.empty?
  end

  private

  def findLineItem(productId)
    lineItems.find { |item| item.productId == productId }
  end
end

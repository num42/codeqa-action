package com.example.shipping

import java.math.BigDecimal

enum class ShippingZone { DOMESTIC, EU, INTERNATIONAL, REMOTE }
enum class ShippingSpeed { STANDARD, EXPRESS, OVERNIGHT }

data class ShippingRate(val baseCost: BigDecimal, val perKgCost: BigDecimal)

class ShippingCalculator {

    // 4 branches — when is appropriate
    fun rateForZone(zone: ShippingZone): ShippingRate = when (zone) {
        ShippingZone.DOMESTIC      -> ShippingRate(BigDecimal("3.99"), BigDecimal("0.50"))
        ShippingZone.EU            -> ShippingRate(BigDecimal("7.99"), BigDecimal("1.20"))
        ShippingZone.INTERNATIONAL -> ShippingRate(BigDecimal("14.99"), BigDecimal("2.50"))
        ShippingZone.REMOTE        -> ShippingRate(BigDecimal("24.99"), BigDecimal("4.00"))
    }

    // 3 branches — when is appropriate
    fun speedMultiplier(speed: ShippingSpeed): BigDecimal = when (speed) {
        ShippingSpeed.STANDARD  -> BigDecimal("1.0")
        ShippingSpeed.EXPRESS   -> BigDecimal("1.75")
        ShippingSpeed.OVERNIGHT -> BigDecimal("3.00")
    }

    // Simple binary — if/else is appropriate here
    fun isFreeShipping(orderTotal: BigDecimal): Boolean =
        if (orderTotal >= BigDecimal("50.00")) true else false

    fun calculate(zone: ShippingZone, speed: ShippingSpeed, weightKg: BigDecimal): BigDecimal {
        val rate = rateForZone(zone)
        val multiplier = speedMultiplier(speed)
        val base = rate.baseCost.add(rate.perKgCost.multiply(weightKg))
        return base.multiply(multiplier).setScale(2, java.math.RoundingMode.HALF_UP)
    }

    // 4 ranges — when with conditions is cleaner than if/else chain
    fun estimatedDays(zone: ShippingZone, speed: ShippingSpeed): Int = when {
        speed == ShippingSpeed.OVERNIGHT                                -> 1
        speed == ShippingSpeed.EXPRESS && zone == ShippingZone.DOMESTIC -> 2
        speed == ShippingSpeed.EXPRESS                                  -> 3
        zone == ShippingZone.DOMESTIC                                   -> 5
        zone == ShippingZone.EU                                         -> 10
        else                                                            -> 21
    }
}

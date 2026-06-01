package com.example.shipping

import java.math.BigDecimal

enum class ShippingZone { DOMESTIC, EU, INTERNATIONAL, REMOTE }
enum class ShippingSpeed { STANDARD, EXPRESS, OVERNIGHT }

data class ShippingRate(val baseCost: BigDecimal, val perKgCost: BigDecimal)

class ShippingCalculator {

    // 4 branches handled with if/else chain — should use when
    fun rateForZone(zone: ShippingZone): ShippingRate {
        if (zone == ShippingZone.DOMESTIC) {
            return ShippingRate(BigDecimal("3.99"), BigDecimal("0.50"))
        } else if (zone == ShippingZone.EU) {
            return ShippingRate(BigDecimal("7.99"), BigDecimal("1.20"))
        } else if (zone == ShippingZone.INTERNATIONAL) {
            return ShippingRate(BigDecimal("14.99"), BigDecimal("2.50"))
        } else {
            return ShippingRate(BigDecimal("24.99"), BigDecimal("4.00"))
        }
    }

    // 3 branches with if/else — should use when
    fun speedMultiplier(speed: ShippingSpeed): BigDecimal {
        if (speed == ShippingSpeed.STANDARD) {
            return BigDecimal("1.0")
        } else if (speed == ShippingSpeed.EXPRESS) {
            return BigDecimal("1.75")
        } else {
            return BigDecimal("3.00")
        }
    }

    fun isFreeShipping(orderTotal: BigDecimal): Boolean =
        if (orderTotal >= BigDecimal("50.00")) true else false

    fun calculate(zone: ShippingZone, speed: ShippingSpeed, weightKg: BigDecimal): BigDecimal {
        val rate = rateForZone(zone)
        val multiplier = speedMultiplier(speed)
        val base = rate.baseCost.add(rate.perKgCost.multiply(weightKg))
        return base.multiply(multiplier).setScale(2, java.math.RoundingMode.HALF_UP)
    }

    // 6 if/else branches — when would be far more readable
    fun estimatedDays(zone: ShippingZone, speed: ShippingSpeed): Int {
        if (speed == ShippingSpeed.OVERNIGHT) {
            return 1
        } else if (speed == ShippingSpeed.EXPRESS && zone == ShippingZone.DOMESTIC) {
            return 2
        } else if (speed == ShippingSpeed.EXPRESS) {
            return 3
        } else if (zone == ShippingZone.DOMESTIC) {
            return 5
        } else if (zone == ShippingZone.EU) {
            return 10
        } else {
            return 21
        }
    }
}

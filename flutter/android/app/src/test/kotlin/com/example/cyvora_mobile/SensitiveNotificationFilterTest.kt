package com.example.cyvora_mobile

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SensitiveNotificationFilterTest {
    @Test
    fun dropsExplicitOneTimeAndAuthenticationCodes() {
        assertTrue(
            SensitiveNotificationFilter.shouldDiscard(
                "Example",
                "Your OTP is 123456.",
            ),
        )
        assertTrue(
            SensitiveNotificationFilter.shouldDiscard(
                "Sign in",
                "Use 482731 to finish authentication.",
            ),
        )
        assertTrue(
            SensitiveNotificationFilter.shouldDiscard(
                "Account",
                "Your password was changed.",
            ),
        )
    }

    @Test
    fun dropsBareNumericCodes() {
        assertTrue(SensitiveNotificationFilter.shouldDiscard("", "123456"))
    }

    @Test
    fun keepsOrdinaryScamWarningText() {
        assertFalse(
            SensitiveNotificationFilter.shouldDiscard(
                "Delivery update",
                "Your parcel is delayed. Review the delivery link.",
            ),
        )
    }
}

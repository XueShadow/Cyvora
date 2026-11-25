package com.example.cyvora_mobile

internal object SensitiveNotificationFilter {
    private val sensitiveWords = Regex(
        """\b(?:otp|one[\s-]?time(?:\s+(?:password|passcode|code))?|verification(?:\s+code)?|security\s+code|authentication(?:\s+code)?|auth(?:entication)?\s+code|login\s+code|sign[\s-]?in\s+code|pass(?:word|code|phrase)|pin)\b""",
        RegexOption.IGNORE_CASE,
    )
    private val authenticationContext = Regex(
        """\b(?:code|verification|authenticate|authentication|login|sign[\s-]?in|security)\b""",
        RegexOption.IGNORE_CASE,
    )
    private val numericCode = Regex("""(?<!\d)\d{4,8}(?!\d)""")
    private val numericOnly = Regex("""^\s*\d{4,8}\s*$""")

    fun shouldDiscard(title: String, text: String): Boolean {
        val content = "$title $text"
        return sensitiveWords.containsMatchIn(content) ||
            (authenticationContext.containsMatchIn(content) &&
                numericCode.containsMatchIn(content)) ||
            numericOnly.matches(title) ||
            numericOnly.matches(text)
    }
}

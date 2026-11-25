package dev.deniz.saha


/** Agent Presence's palette (github.com/DenizTanisman/agent-presence), its blue swapped for the island's orange. */
internal object Renk {
    // Surfaces.
    const val SURFACE = 0xFF0E0E10.toInt()          // card
    const val BORDER = 0x14FFFFFF                    // 1 px hairline
    const val PANEL = 0x0AFFFFFF                     // inner panels (the task list)
    const val DIVIDER = 0x0FFFFFFF
    const val CAPSULE = 0xFF141416.toInt()
    const val CHIP = 0xFF0E0E10.toInt()              // the disc behind a minimal circle
    const val GLYPH = 0xFF2C2C2E.toInt()             // neutral app glyph

    // Text: never pure white on black.
    const val TEXT = 0xFFF5F5F7.toInt()
    const val TEXT2 = 0xFF9A9AA2.toInt()
    const val TEXT_DONE = 0xFFC7C7CC.toInt()

    // Accents and their text colors.
    const val BLUE = 0xFFFF6A2B.toInt()
    const val BLUE_TEXT = 0xFFFFA477.toInt()
    const val GREEN = 0xFF30D158.toInt()
    const val GREEN_TEXT = 0xFF4ADE80.toInt()
    const val AMBER = 0xFFFF9F0A.toInt()
    const val AMBER_TEXT = 0xFFFFB340.toInt()
    const val RED = 0xFFFF453A.toInt()
    const val RED_TEXT = 0xFFFF6961.toInt()
    const val PENDING = 0xFF8E8E93.toInt()

    // The step circle (SPEC §3).
    const val BLUE_ORBIT = 0xFFFF6A2B.toInt()
    const val BLUE_FILL = 0xFF3A1A0C.toInt()
    const val PENDING_FILL = 0xFF2C2C2E.toInt()
    const val PENDING_TEXT = PENDING

    // Directive capsule gradients (SPEC §4).
    val DONT_GRADIENT = intArrayOf(0xFFFF5A4F.toInt(), 0xFFE5332A.toInt())
    val DO_GRADIENT = intArrayOf(0xFF34D399.toInt(), 0xFF16A34A.toInt())

    /** [color] with its alpha replaced by [share] (0..1). */
    fun alpha(color: Int, share: Float): Int = (color and 0x00FFFFFF) or ((share * 255).toInt().coerceIn(0, 255) shl 24)
}

/** System font (One UI Sans on Samsung), semibold for titles and labels. */
internal object Yazi {
    val normal: android.graphics.Typeface =
        if (android.os.Build.VERSION.SDK_INT >= 28) android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, 400, false) else android.graphics.Typeface.DEFAULT
    val kalin: android.graphics.Typeface =
        if (android.os.Build.VERSION.SDK_INT >= 28) android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, 600, false) else android.graphics.Typeface.DEFAULT_BOLD
}

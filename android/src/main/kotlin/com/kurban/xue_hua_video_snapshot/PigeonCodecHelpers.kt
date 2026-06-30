package com.kurban.xue_hua_video_snapshot

/** Coerces Pigeon message arguments to [Long]. */
internal fun pigeonLong(value: Any?): Long = when (value) {
    is Long -> value
    is Int -> value.toLong()
    is Number -> value.toLong()
    else -> throw IllegalArgumentException("Expected numeric pigeon argument, got $value")
}

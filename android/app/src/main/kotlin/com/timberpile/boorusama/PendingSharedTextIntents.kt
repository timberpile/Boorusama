package com.timberpile.boorusama

/** Keeps text shares until Dart has subscribed and handled the launch share. */
internal class PendingSharedTextIntents<T>(private val deliver: (T) -> Unit) {
    private var listening = false
    private val pending = ArrayDeque<T>()

    fun enqueueIfWaiting(intent: T): Boolean {
        if (listening) return false
        pending.addLast(intent)
        return true
    }

    fun resume() {
        listening = true
        while (pending.isNotEmpty()) deliver(pending.removeFirst())
    }

    fun pause() {
        listening = false
    }

    fun clear() {
        pending.clear()
        pause()
    }
}

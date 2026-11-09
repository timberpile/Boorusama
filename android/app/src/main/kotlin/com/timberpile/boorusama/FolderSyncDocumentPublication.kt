package com.timberpile.boorusama

/** The final immutable name becomes visible only after staged bytes verify.
 * A failed first write cannot poison a publisher's stable identity.json name.
 * discardStaged must check that the created document still has its staging name.
 */
internal fun <D : Any> publishImmutableSyncDocument(
    bytes: ByteArray,
    findFinal: () -> D?,
    createStaged: () -> D,
    writeStaged: (D, ByteArray) -> Unit,
    read: (D) -> ByteArray,
    promote: (D) -> D,
    discardStaged: (D) -> Unit
) {
    findFinal()?.let { require(read(it).contentEquals(bytes)); return }
    val staged = createStaged()
    var promoted = false
    try {
        writeStaged(staged, bytes)
        require(read(staged).contentEquals(bytes))
        val winner = findFinal()
        if (winner != null) {
            require(read(winner).contentEquals(bytes))
            return
        }
        val published = promote(staged)
        promoted = true
        require(read(published).contentEquals(bytes))
    } finally {
        if (!promoted) runCatching { discardStaged(staged) }
    }
}

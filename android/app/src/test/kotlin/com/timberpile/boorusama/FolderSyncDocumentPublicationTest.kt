package com.timberpile.boorusama

import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

class FolderSyncDocumentPublicationTest {
    private class Document(var name: String, var bytes: ByteArray = byteArrayOf())
    private class Store {
        val documents = mutableListOf<Document>()
        var interruptWrite = false
        var truncate = false
        var failAfterRename = false
        fun publish(bytes: ByteArray) = publishImmutableSyncDocument(
            bytes,
            findFinal = { documents.singleOrNull { it.name == "identity.json" } },
            createStaged = { Document("identity.uuid.partial").also { documents.add(it) } },
            writeStaged = { document, content ->
                document.bytes = if (truncate || interruptWrite) content.take(1).toByteArray() else content.copyOf()
                if (interruptWrite) throw IOException("Interrupted first write")
            },
            read = { it.bytes },
            promote = { document ->
                document.name = "identity.json"
                if (failAfterRename) throw IOException("Provider reported failure after rename")
                document
            },
            discardStaged = { document -> if (document.name.endsWith(".partial")) documents.remove(document) }
        )
    }
    @Test fun interruptedFirstWriteDoesNotPoisonStableIdentityAndCanRetry() {
        val store = Store()
        store.interruptWrite = true
        assertThrows(IOException::class.java) { store.publish(byteArrayOf(1, 2, 3)) }
        assertTrue(store.documents.none { it.name == "identity.json" })
        store.interruptWrite = false
        store.publish(byteArrayOf(1, 2, 3))
        assertArrayEquals(byteArrayOf(1, 2, 3), store.documents.single().bytes)
    }
    @Test fun truncatedStagingNeverBecomesCommittedIdentity() {
        val store = Store()
        store.truncate = true
        assertThrows(IllegalArgumentException::class.java) { store.publish(byteArrayOf(1, 2, 3)) }
        assertTrue(store.documents.isEmpty())
    }
    @Test fun existingDifferentIdentityIsPreserved() {
        val store = Store()
        store.publish(byteArrayOf(1, 2, 3))
        assertThrows(IllegalArgumentException::class.java) { store.publish(byteArrayOf(4, 5, 6)) }
        assertArrayEquals(byteArrayOf(1, 2, 3), store.documents.single().bytes)
    }
    @Test fun postRenameFailureDoesNotDeleteFinalThroughOldDocumentHandle() {
        val store = Store()
        store.failAfterRename = true
        assertThrows(IOException::class.java) { store.publish(byteArrayOf(1, 2, 3)) }
        assertEquals("identity.json", store.documents.single().name)
        store.failAfterRename = false
        store.publish(byteArrayOf(1, 2, 3))
        assertEquals(1, store.documents.size)
    }
}

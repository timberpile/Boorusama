package com.timberpile.boorusama

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FolderSyncRetentionPathTest {
    private val owner = "10000000-0000-4000-8000-000000000001"
    private val source = "10000000-0000-4000-8000-000000000002"
    @Test fun `retention accepts only exact own immutable revision paths`() {
        assertTrue(FolderSyncChannel.isOwnedRevision("devices/$owner/catalog/1.json".split('/'), owner))
        assertTrue(FolderSyncChannel.isOwnedRevision("devices/$owner/collections/bookmarks/$source/12.bsexport".split('/'), owner))
        for (path in listOf(
            "devices/$source/catalog/1.json",
            "devices/$owner/identity.json",
            "devices/$owner/catalog/1.bsexport",
            "devices/$owner/catalog/001.json",
            "devices/$owner/catalog/9007199254740992.json",
            "devices/$owner/collections/profiles/$source/1.json",
            "devices/$owner/collections/bookmarks/$source/1.partial",
            "devices/$owner/collections/bookmarks/$source/../1.json"
        )) assertFalse(path, FolderSyncChannel.isOwnedRevision(path.split('/'), owner))
    }
}

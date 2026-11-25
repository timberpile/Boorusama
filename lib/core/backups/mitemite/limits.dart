const miteMiteProtocol = 1;
const miteMiteRoot = 'v1';
const miteMiteMaxBytes = 32 * 1024 * 1024;

// Preparation accounts for both serialized and decoded data. A connected
// Bookmark subtree can retain several snapshots before its atomic commit.
const miteMiteMaxBookmarkPackagePreparationBytes = 128 * 1024 * 1024;
const miteMiteMaxBookmarkBatchPreparationBytes = 256 * 1024 * 1024;
const miteMiteMaxMetadataBytes = 256 * 1024;
const miteMiteMaxEntries = 4096;
const miteMiteMaxSequence = 9007199254740991;

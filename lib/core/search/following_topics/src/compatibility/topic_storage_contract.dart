// Persisted contracts from versions before Following Topics. Keep these wire
// identifiers stable so existing Hive data, backups and imports remain readable.
// Application classes, providers, files and translation keys use current names.
const followingTopicsBackupSourceId = 'pinned_searches';
const topicFeedsBackupSourceId = 'following_feeds';
const followingTopicsBoxName = 'pinned_search_subscriptions';
const topicOrganizationBoxName = 'pinned_search_folders';
const followingTopicsHiveFileName = '$followingTopicsBoxName.hive';
const topicOrganizationHiveFileName = '$topicOrganizationBoxName.hive';

const legacyFollowingTopicSortKey = 'pinnedSearchSort';
const legacyTopicFeedMemberSortKey = 'followingFeedMemberSort';
const legacyFollowingTopicsEnabledKey = 'pinnedSearchesEnabled';
const legacyTopicFeedsEnabledKey = 'followingFeedsEnabled';
const legacyFollowingTopicsPath = '/pinned-searches';
const legacyTopicFeedsPath = '/following-feeds';
const legacyTopicUpdatesSettingsId = 'pinned_searches_and_feeds';

import 'package:i18n/i18n.dart';

import '../../../developer_options/l10n.dart';
import 'settings_search.dart';

/// Uses the same translations as the controls, without building settings pages
/// or initializing their services. Only currently available categories are added.
List<SettingsSearchItem> buildSettingsSearchCatalog(
  Translations t, {
  required Map<String, String> sections,
  required bool isMobile,
}) {
  final items = <SettingsSearchItem>[
    for (final section in sections.entries)
      SettingsSearchItem(
        id: section.key,
        sectionId: section.key,
        sectionTitle: section.value,
        title: section.value,
        keywords: _categoryAliases[section.key] ?? const [],
      ),
  ];

  void add(
    String sectionId,
    String id,
    String title, {
    String description = '',
    List<String> keywords = const [],
  }) {
    final sectionTitle = sections[sectionId];
    if (sectionTitle == null) return;

    items.add(
      SettingsSearchItem(
        id: '$sectionId.$id',
        sectionId: sectionId,
        sectionTitle: sectionTitle,
        title: title,
        description: description,
        keywords: [id, ...keywords],
      ),
    );
  }

  final settings = t.settings;
  final appearance = settings.appearance;
  final grid = settings.image_grid;
  add(
    'appearance',
    'theme',
    settings.theme.theme,
    keywords: ['dark light system colors', settings.theme.dynamic_color],
  );
  add(
    'appearance',
    'grid_size',
    grid.grid_size.grid_size,
    keywords: ['columns thumbnails'],
  );
  add(
    'appearance',
    'image_list',
    settings.image_list.image_list,
    keywords: ['grid masonry layout'],
  );
  add('appearance', 'thumbnail_quality', grid.thumbnail_quality);
  add(
    'appearance',
    'result_layout',
    settings.result_layout.result_layout,
    keywords: [
      'infinite scroll pagination',
      settings.page_indicator.page_indicator,
    ],
  );
  add(
    'appearance',
    'posts_per_page',
    settings.performance.posts_per_page,
    description: settings.performance.posts_per_page_explain,
  );
  add('appearance', 'show_scores', appearance.show_scores);
  add('appearance', 'show_bookmark_count', appearance.show_bookmark_count);
  add(
    'appearance',
    'show_post_list_config_header',
    appearance.show_post_list_config_header,
  );
  add(
    'appearance',
    'blur_explicit_media',
    appearance.blur_explicit_media,
    keywords: ['nsfw sensitive'],
  );
  add(
    'appearance',
    'auto_play_gif',
    appearance.auto_play_gif,
    keywords: ['autoplay animation'],
  );
  add('appearance', 'spacing', grid.spacing);
  add('appearance', 'corner_radius', grid.corner_radius);
  add('appearance', 'padding', grid.padding);
  add('appearance', 'aspect_ratio', grid.aspect_ratio);

  final download = settings.download;
  add(
    'download',
    'quality',
    download.quality,
    keywords: [
      download.qualities.original,
      download.qualities.sample,
      download.qualities.preview,
    ],
  );
  if (isMobile) {
    add(
      'download',
      'network',
      download.network.title,
      description: download.network.description,
      keywords: [
        'wifi wi-fi mobile cellular',
        download.network.wifi_only,
        download.network.ask_on_mobile_data,
      ],
    );
  }
  add(
    'download',
    'notifications',
    t.bulk_downloads.options.enable_notification,
  );
  add(
    'download',
    'skip_existing_files',
    download.skip_existing_files,
    description: download.skip_existing_files_explanation,
    keywords: ['duplicates'],
  );

  final storage = settings.data_and_storage;
  add(
    'data_and_storage',
    'storage',
    storage.storage,
    keywords: ['disk space free used'],
  );
  add(
    'data_and_storage',
    'image_cache',
    storage.image_only_cache,
    keywords: [settings.performance.clear_cache],
  );
  add(
    'data_and_storage',
    'video_cache',
    storage.video_cache,
    keywords: [settings.performance.clear_cache],
  );
  add(
    'data_and_storage',
    'tag_cache',
    storage.tag_cache,
    keywords: [settings.performance.clear_cache],
  );
  add(
    'data_and_storage',
    'all_cache',
    storage.all_cache,
    keywords: [settings.performance.clear_cache],
  );
  add(
    'data_and_storage',
    'clear_cache_on_start_up',
    storage.clear_cache_on_start_up,
  );
  add(
    'data_and_storage',
    'image_cache_limit',
    storage.image_cache_limit,
    description: storage.image_cache_limit_description,
    keywords: ['maximum size'],
  );
  add(
    'data_and_storage',
    'video_cache_limit',
    storage.video_cache_limit,
    description: storage.video_cache_limit_description,
    keywords: ['maximum size'],
  );
  add(
    'data_and_storage',
    'advanced',
    t.bookmark.maintenance.advanced,
    keywords: ['bookmarks maintenance hydration repair'],
  );

  final search = settings.search;
  add(
    'search',
    'auto_focus_search_bar',
    search.auto_focus_search_bar,
    keywords: ['keyboard autofocus'],
  );
  add(
    'search',
    'persistent_search_bar',
    search.search_bar.scroll_behavior.persistent,
    description: search.search_bar.scroll_behavior.persistent_description,
  );
  add(
    'search',
    'search_bar_position',
    search.search_bar.position.search_bar_position,
    keywords: ['top bottom'],
  );
  add(
    'search',
    'hide_bookmarked_posts',
    search.hide_bookmarked_posts_from_search_results,
    keywords: ['filter bookmarks'],
  );

  final refresh = settings.topic_updates;
  add(
    'topic_updates',
    'automatic_refresh',
    refresh.enabled,
    keywords: ['following topics subscriptions updates'],
  );
  add('topic_updates', 'following_topics', refresh.following_topics);
  add('topic_updates', 'topic_feeds', refresh.topic_feeds);
  add(
    'topic_updates',
    'refresh_interval',
    refresh.interval,
    keywords: [refresh.adaptive, refresh.fixed, refresh.fixed_interval],
  );
  add(
    'topic_updates',
    'wifi_only',
    refresh.wifi_only,
    keywords: ['wi-fi ethernet network'],
  );

  final accessibility = settings.accessibility;
  add(
    'accessibility',
    'reduce_animations',
    accessibility.reduce_animations,
    description: accessibility.reduce_animations_description,
    keywords: ['motion'],
  );
  add(
    'accessibility',
    'volume_navigation',
    accessibility.volume_navigation,
    description: accessibility.volume_navigation_description,
    keywords: ['buttons keys'],
  );
  add(
    'accessibility',
    'haptic_feedback',
    accessibility.haptic_feedback.haptic_feedback,
    keywords: ['vibration'],
  );

  final viewer = settings.image_viewer;
  add(
    'viewer',
    'post_quality',
    viewer.post_quality,
    keywords: ['original sample image resolution'],
  );
  add(
    'viewer',
    'ui_overlay',
    settings.image_details.ui_overlay.ui_overlay,
    keywords: ['controls toolbar'],
  );
  add(
    'viewer',
    'swipe_mode',
    viewer.swipe_mode,
    description: viewer.swipe_mode_disclaimer,
    keywords: [viewer.swipe_modes.horizontal, viewer.swipe_modes.vertical],
  );
  add(
    'viewer',
    'load_original_on_zoom',
    viewer.load_original_on_zoom,
    description: viewer.load_original_on_zoom_description,
  );
  add(
    'viewer',
    'snap_zoom_to_fit',
    viewer.snap_zoom_to_fit,
    description: viewer.snap_zoom_to_fit_description,
  );
  add('viewer', 'double_tap_zoom', viewer.double_tap_zoom_behavior);
  add(
    'viewer',
    'auto_adjust_comic_strips',
    viewer.auto_adjust_comic_strips,
    description: viewer.auto_adjust_comic_strips_description,
  );
  add('viewer', 'slideshow_mode', viewer.slideshow_mode);
  add(
    'viewer',
    'slideshow_interval',
    viewer.slideshow_interval,
    description: viewer.slideshow_interval_explanation,
  );
  add('viewer', 'slideshow_skip', viewer.slideshow_skip);
  add(
    'viewer',
    'slideshow_video_behavior',
    viewer.slideshow_video_behavior,
    description: viewer.slideshow_video_behavior_explanation,
  );
  add(
    'viewer',
    'video_player_engine',
    viewer.video.video_player_engine,
    keywords: ['playback decoder'],
  );
  add(
    'viewer',
    'mute_video',
    viewer.mute_video,
    keywords: ['sound audio volume'],
  );
  add(
    'viewer',
    'double_tap_seek',
    viewer.double_tap_seek,
    keywords: ['video forward rewind'],
  );
  add(
    'viewer',
    'enable_video_cache',
    viewer.enable_video_cache,
    description: viewer.enable_video_cache_description,
  );

  final privacy = settings.privacy;
  add(
    'privacy',
    'app_lock',
    privacy.app_lock.title,
    keywords: ['pin passcode biometric fingerprint face unlock timeout'],
  );
  add(
    'privacy',
    'hide_app_preview',
    privacy.app_lock.hide_app_preview,
    description: privacy.app_lock.hide_app_preview_description,
    keywords: ['recents background'],
  );

  add(
    'developer_options',
    'block_automatic_media',
    t.developerOptions.blockAutomaticMedia,
    description: t.developerOptions.blockAutomaticMediaDescription,
  );
  return items;
}

const _categoryAliases = <String, List<String>>{
  'appearance': ['appearance theme layout'],
  'language': ['language locale translation'],
  'download': ['download folder directory location path'],
  'data_and_storage': ['data storage cache'],
  'backup_and_restore': ['backup restore export import'],
  'search': ['search'],
  'topic_updates': [
    'topics topic feeds following',
  ],
  'accessibility': ['accessibility'],
  'viewer': ['image viewer video playback slideshow'],
  'privacy': ['privacy security'],
  'developer_options': ['developer options debug'],
};

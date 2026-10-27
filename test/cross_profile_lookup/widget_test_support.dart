import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Image loading is disabled by the lookup widget fixtures.
class UnusedLookupImageCache extends Fake implements ImageCacheManager {}

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../types/search_subscription_repository.dart';
import 'hive/search_subscription_hive_object.dart';
import 'hive/search_subscription_repository_hive.dart';

final searchSubscriptionRepositoryProvider =
    FutureProvider<SearchSubscriptionRepository>((ref) async {
      final box = await Hive.openBox<SearchSubscriptionHiveObject>(
        'pinned_search_subscriptions',
      );
      ref.onDispose(() async {
        await box.close();
      });
      return HiveSearchSubscriptionRepository(box: box);
    });

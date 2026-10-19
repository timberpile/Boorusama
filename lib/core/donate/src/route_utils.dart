// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../router.dart';
import 'donation_page.dart';

Future<void> goToDonationPage(WidgetRef ref) {
  return ref.pushNamedRoute(
    '/donate',
    extra: const DonationPage(),
  );
}

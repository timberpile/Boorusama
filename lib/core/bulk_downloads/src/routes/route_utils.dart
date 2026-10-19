// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../router.dart';
import 'internal_routes.dart';

Future<void> goToBulkDownloadPage(
  BuildContext context,
  List<String>? tags, {
  required WidgetRef ref,
}) async {
  if (tags != null) {
    return goToNewBulkDownloadTaskPage(
      ref,
      context,
      initialValue: tags,
    );
  } else {
    return goToBulkDownloadManagerPage(ref);
  }
}

Future<void> goToBulkDownloadManagerPage(
  WidgetRef ref, {
  bool go = false,
}) async {
  final uri = Uri(
    pathSegments: [
      '',
      'bulk_downloads',
    ],
  ).toString();
  if (go) {
    ref.router.go(uri);
  } else {
    await ref.pushRoute(uri);
  }
}

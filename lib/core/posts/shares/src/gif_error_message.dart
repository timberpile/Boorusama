import 'package:flutter/services.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'gif_export_contract.dart';

String gifErrorMessage(BuildContext context, GifConversionException error) =>
    switch (error.failure) {
      GifConversionFailure.oversized => context.t.post.action.gif_too_large,
      GifConversionFailure.network => context.t.post.action.share_network_error,
      GifConversionFailure.authentication =>
        context.t.post.action.share_authentication_error,
      GifConversionFailure.storage => context.t.post.action.share_storage_error,
      _ =>
        '${context.t.post.action.gif_conversion_error} '
            '[GIF-${error.stage?.name ?? 'setup'}-${error.failure.name}]'
            '${_missingGifNativeCall(error.cause)}',
    };

String _missingGifNativeCall(Object? cause) {
  if (cause is! MissingPluginException) return '';
  // Only expose the framework's method/channel identifiers, not arbitrary
  // exception messages which could contain URLs or authentication data.
  final match = RegExp(
    r'^No implementation found for method ([\w]+) on channel ([\w./-]+)$',
  ).firstMatch(cause.message ?? '');
  return match == null ? '' : '\n[NATIVE:${match[1]}@${match[2]}]';
}

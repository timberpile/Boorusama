// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pasteboard/pasteboard.dart';

// Project imports:

abstract class AppClipboard {
  static const exportMimeType = 'application/vnd.boorusama.export';
  static const exportUti = 'com.timberpile.boorusama.export';
  static const _exportChannel = MethodChannel(
    'com.timberpile.boorusama/export_clipboard',
  );

  static Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  static Future<void> copyImageBytes(Uint8List bytes) =>
      Pasteboard.writeImage(bytes);

  static Future<String?> paste(String format) async {
    final data = await Clipboard.getData(format);
    return data?.text;
  }

  static Future<void> copyExport(String encoded) async {
    try {
      await _exportChannel.invokeMethod<void>('writeExport', {
        'mimeType': exportMimeType,
        'uti': exportUti,
        'text': encoded,
      });
    } on MissingPluginException {
      await copy(encoded);
    }
  }

  static Future<bool> containsExport() async {
    try {
      return await _exportChannel.invokeMethod<bool>('containsExport', {
            'mimeType': exportMimeType,
            'uti': exportUti,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<String?> pasteExport() async {
    try {
      final value = await _exportChannel.invokeMethod<String>('readExport', {
        'mimeType': exportMimeType,
        'uti': exportUti,
      });
      return value ?? paste('text/plain');
    } on MissingPluginException {
      return paste('text/plain');
    }
  }

  static Future<void> copyAndToast(
    BuildContext context,
    String text, {
    required String message,
  }) async {
    await copy(text);
    showToast(
      message,
      position: ToastPosition.bottom,
      textPadding: const EdgeInsets.all(8),
      duration: KurumiDurations.shortToast,
    );
  }

  static Future<void> copyWithDefaultToast(
    BuildContext context,
    String text,
  ) => copyAndToast(
    context,
    text,
    message: 'Copied',
  );
}

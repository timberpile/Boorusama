import 'dart:async';

import 'package:boorusama/foundation/picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const picker = _DirectoryPicker();

  test('waits for the selected directory write before completing', () async {
    final write = Completer<void>();
    var finished = false;
    final pick = pickDirectoryPath(
      picker: picker,
      onPick: (_) => write.future,
    ).then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(finished, false);
    write.complete();
    await pick;
    expect(finished, true);
  });

  test('reports asynchronous destination write failures', () async {
    Object? reported;
    await pickDirectoryPath(
      picker: picker,
      onPick: (_) => Future<void>.error(
        StateError('Destination is unavailable'),
      ),
      onError: (error) => reported = error,
    );
    expect(reported, isA<StateError>());
  });
}

class _DirectoryPicker implements AppFilePicker {
  const _DirectoryPicker();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async =>
      '/selected';

  @override
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    bool customFileType = false,
  }) => throw UnimplementedError();
}

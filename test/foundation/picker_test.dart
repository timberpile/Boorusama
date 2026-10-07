import 'dart:async';

import 'package:boorusama/foundation/picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FilePickerPlatform original;
  setUp(() {
    original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _DirectoryPicker();
  });
  tearDown(() => FilePickerPlatform.instance = original);

  test('waits for the selected directory write before completing', () async {
    final write = Completer<void>();
    var finished = false;
    final pick = pickDirectoryPath(
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
      onPick: (_) => Future<void>.error(
        StateError('Destination is unavailable'),
      ),
      onError: (error) => reported = error,
    );
    expect(reported, isA<StateError>());
  });
}

class _DirectoryPicker extends FilePickerPlatform {
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
    AndroidSAFOptions? androidSafOptions,
  }) async => '/selected';
}

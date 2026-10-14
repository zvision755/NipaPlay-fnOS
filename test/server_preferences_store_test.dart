import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nipaplay/services/server_preferences_store.dart';

void main() {
  test('server preferences survive reopening and remove credentials on logout', () async {
    final parent = await Directory('.porting/preferences-regression').create(recursive: true);
    final directory = await parent.createTemp();
    try {
      final file = File('${directory.path}/preferences.json');
      final store = await ServerPreferencesStore.open(file);
      await Future.wait([
        store.setValue('String', 'flutter.test_token', 'fake-test-credential'),
        store.setValue('StringList', 'flutter.folders', <String>['sample']),
      ]);
      final reopened = await ServerPreferencesStore.open(file);
      expect((await reopened.getAll())['flutter.test_token'], 'fake-test-credential');
      expect((await reopened.getAll())['flutter.folders'], ['sample']);
      expect((await file.stat()).mode & 0x1ff, 0x180); // 0600
      await reopened.remove('flutter.test_token');
      expect((await (await ServerPreferencesStore.open(file)).getAll()).containsKey('flutter.test_token'), false);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

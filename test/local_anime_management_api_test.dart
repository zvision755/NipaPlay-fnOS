import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';
import 'package:nipaplay/models/watch_history_model.dart';
import 'package:nipaplay/providers/service_provider.dart';
import 'package:nipaplay/services/local_media_management_api.dart';
import 'package:nipaplay/utils/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory('.porting/library-actions-regression').absolute
    ..createSync(recursive: true);
  SharedPreferences.setMockInitialValues({
    'nipaplay_scanned_folders': [root.path]
  });
  StorageService.debugAppStorageDirectoryOverride = root;
  final api = LocalMediaManagementApi();
  Future<Response> remove(String id) => api
      .router(Request('POST', Uri.parse('http://localhost/animes/$id/remove')));
  test(
      'remove only library records, retain source file and folder registration',
      () async {
    final file = File('${root.path}/retained.txt')
      ..writeAsStringSync('source file');
    await WatchHistoryManager.addOrUpdateHistory(WatchHistoryItem(
        filePath: file.path,
        animeName: 'Disposable fixture',
        animeId: 9999001,
        watchProgress: .5,
        lastPosition: 50,
        duration: 100,
        lastWatchTime: DateTime.now(),
        isFromScan: false));
    await ServiceProvider.watchHistoryProvider.refresh();
    final response = await remove('9999001');
    expect(response.statusCode, 200);
    expect(jsonDecode(await response.readAsString())['data']['removed'], 1);
    expect(await WatchHistoryManager.getHistoryItem(file.path), isNull);
    expect(await file.readAsString(), 'source file');
    expect(ServiceProvider.scanService.scannedFolders, contains(root.path));
  });
  test('reject invalid ID and records belonging to another media source',
      () async {
    expect((await remove('invalid')).statusCode, 400);
    const path = 'https://media.example.invalid/video';
    await WatchHistoryManager.addOrUpdateHistory(WatchHistoryItem(
        filePath: path,
        animeName: 'Other source fixture',
        animeId: 9999002,
        watchProgress: 0,
        lastPosition: 0,
        duration: 0,
        lastWatchTime: DateTime.now(),
        isFromScan: false));
    expect((await remove('9999002')).statusCode, 409);
    expect(await WatchHistoryManager.getHistoryItem(path), isNotNull);
  });
}

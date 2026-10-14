import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nipaplay/models/watch_history_model.dart';
import 'package:nipaplay/services/batch_danmaku_match_persistence.dart';
import 'package:nipaplay/utils/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  StorageService.debugAppStorageDirectoryOverride = Directory('.porting/batch-match-regression')..createSync(recursive: true);
  test('manual matching preserves real progress and uses original shared history', () async {
    final path = '${StorageService.debugAppStorageDirectoryOverride!.path}/episode.avi';
    await WatchHistoryManager.addOrUpdateHistory(WatchHistoryItem(
      filePath: path, animeName: 'Before', watchProgress: 0.5,
      lastPosition: 600, duration: 1200, lastWatchTime: DateTime.now(), isFromScan: false));
    final count = await BatchDanmakuMatchPersistence.apply(animeId: 12345,
      animeTitle: 'Test anime', mappings: [{'filePath': path, 'episodeId': 67890, 'episodeTitle': 'Episode 1'}]);
    expect(count, 1);
    final saved = await WatchHistoryManager.getHistoryItem(path);
    expect(saved!.animeId, 12345);
    expect(saved.episodeId, 67890);
    expect(saved.watchProgress, 0.5);
    expect(saved.lastPosition, 600);
    expect(saved.duration, 1200);
  });
}

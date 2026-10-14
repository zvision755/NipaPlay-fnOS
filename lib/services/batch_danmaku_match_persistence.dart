import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:nipaplay/models/watch_history_model.dart';

/// Original library-management persistence, shared by native UI and Web API.
class BatchDanmakuMatchPersistence {
  static Future<int> apply({required int animeId, required String animeTitle,
    required List<Map<String, dynamic>> mappings,
    String Function(String)? fileNameForPath}) async {
    int successCount = 0;
    for (final mapping in mappings) {
      final filePath = mapping['filePath']?.toString() ?? '';
      final fileName = mapping['fileName']?.toString() ??
          (fileNameForPath ?? p.basename)(filePath);
      final episodeId = mapping['episodeId'];
      final episodeTitle = mapping['episodeTitle']?.toString() ?? '';

      if (filePath.isEmpty || episodeId is! int || episodeId <= 0) continue;

      try {
        final existingHistory =
            await WatchHistoryManager.getHistoryItem(filePath);

        // 仅从已解除匹配的旧路径迁移进度，同集其他版本保留。
        WatchHistoryItem? migratedHistory;
        if (existingHistory == null && animeId > 0 && episodeId > 0) {
          migratedHistory =
              await WatchHistoryManager.getClearedHistoryItemByEpisode(
            animeId,
            episodeId,
          );
        }

        final sourceForProgress = existingHistory ?? migratedHistory;
        final preserveProgress = sourceForProgress != null &&
            sourceForProgress.watchProgress > 0.01 &&
            !sourceForProgress.isFromScan;

        final updatedHistory = WatchHistoryItem(
          filePath: filePath,
          animeName: animeTitle.isNotEmpty
              ? animeTitle
              : (sourceForProgress?.animeName ??
                  p.basenameWithoutExtension(fileName)),
          episodeTitle: episodeTitle.isNotEmpty
              ? episodeTitle
              : sourceForProgress?.episodeTitle,
          episodeId: episodeId,
          animeId: animeId,
          watchProgress: preserveProgress
              ? sourceForProgress.watchProgress
              : (sourceForProgress?.watchProgress ?? 0.0),
          lastPosition: preserveProgress
              ? sourceForProgress.lastPosition
              : (sourceForProgress?.lastPosition ?? 0),
          duration: sourceForProgress?.duration ?? 0,
          lastWatchTime: DateTime.now(),
          thumbnailPath: sourceForProgress?.thumbnailPath,
          isFromScan: sourceForProgress?.isFromScan ?? false,
          videoHash: sourceForProgress?.videoHash,
        );
        await WatchHistoryManager.addOrUpdateHistory(updatedHistory);

        // 仅删除已解除匹配的进度来源。
        if (migratedHistory != null && migratedHistory.filePath != filePath) {
          await WatchHistoryManager.removeHistoryItem(migratedHistory.filePath);
        }

        successCount++;
      } catch (e) {
        debugPrint('批量更新匹配失败: $filePath -> $episodeId ($e)');
      }
    }


    return successCount;
  }
}

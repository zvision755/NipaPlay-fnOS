import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:nipaplay/utils/storage_service.dart';

/// Server-side compatibility work; the source file is always read-only.
class BrowserMediaService {
  static final Map<String, Future<File>> _pending = {};

  static Future<File> browserVideo(File source) async {
    if (p.extension(source.path).toLowerCase() != '.avi') return source;
    final stat = await source.stat();
    final key = sha256
        .convert(utf8.encode(
            '${source.absolute.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}'))
        .toString();
    final root = await StorageService.getCacheDirectory();
    final dir =
        await Directory('${root.path}/browser-video').create(recursive: true);
    final output = File('${dir.path}/$key.mp4');
    if (await output.exists()) return output;
    final future = _pending.putIfAbsent(key, () async {
      final temporary =
          '${dir.path}/$key-${DateTime.now().microsecondsSinceEpoch}.mp4';
      final process = await Process.start('ffmpeg', [
        '-nostdin',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        source.path,
        '-map',
        '0:v:0',
        '-map',
        '0:a:0?',
        '-c:v',
        'libx264',
        '-preset',
        'fast',
        '-crf',
        '20',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '160k',
        '-movflags',
        '+faststart',
        temporary,
      ]);
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final stdoutFuture = process.stdout.drain<void>();
      final exit = await process.exitCode.timeout(const Duration(minutes: 15),
          onTimeout: () {
        process.kill();
        throw TimeoutException('AVI conversion timed out');
      });
      await stdoutFuture;
      final error = await stderrFuture;
      if (exit != 0) throw StateError('FFmpeg conversion failed: $error');
      return File(temporary).rename(output.path);
    });
    try {
      return await future;
    } finally {
      _pending.remove(key);
    }
  }

  static Future<List<Map<String, dynamic>>> subtitleTracks(
      String filePath) async {
    if (p.extension(filePath).toLowerCase() != '.mkv') return [];
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      's',
      '-show_entries',
      'stream=index,codec_name:stream_tags=language,title',
      '-of',
      'json',
      filePath,
    ]);
    if (result.exitCode != 0) throw StateError('Subtitle probe failed');
    final data = jsonDecode(result.stdout as String) as Map;
    return [
      for (final raw in data['streams'] as List)
        if (const ['subrip', 'ass', 'ssa'].contains(raw['codec_name']))
          {
            'index': raw['index'],
            'name': raw['tags']?['title'] ??
                raw['tags']?['language'] ??
                '字幕 ${raw['index']}',
            'codec': raw['codec_name'],
            'source': 'embedded'
          }
    ];
  }

  static Future<String> extractSubtitle(String filePath, int index,
      {bool preserveAss = false}) async {
    final tracks = await subtitleTracks(filePath);
    if (!tracks.any((t) => t['index'] == index))
      throw ArgumentError('Invalid subtitle track');
    final result = await Process.run('ffmpeg', [
      '-nostdin',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      filePath,
      '-map',
      '0:$index',
      '-f',
      preserveAss ? 'ass' : 'srt',
      'pipe:1',
    ]);
    if (result.exitCode != 0) throw StateError('Subtitle extraction failed');
    return result.stdout as String;
  }
}

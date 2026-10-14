import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nipaplay/models/watch_history_model.dart';
import 'package:nipaplay/services/local_media_management_api.dart';
import 'package:nipaplay/services/local_media_share_service.dart';
import 'package:nipaplay/utils/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fixtures;
  late File video;
  late LocalMediaManagementApi api;
  late SharedEpisodeInfo episode;
  final bytes = List<int>.generate(4096, (i) => i % 251);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    fixtures = await Directory('.porting/http-fixtures-$pid').absolute.create(recursive: true);
    StorageService.debugAppStorageDirectoryOverride = fixtures;
    video = await File('${fixtures.path}/episode.mp4').writeAsBytes(bytes);
    await File('${fixtures.path}/episode.ass').writeAsString('[Script Info]\n');
    api = LocalMediaManagementApi();
    await api.router(Request('POST', Uri.parse('http://localhost/folders'),
      body: jsonEncode({'path': fixtures.path, 'scan': false})));
    episode = SharedEpisodeInfo(shareId: 'test', historyItem: WatchHistoryItem(
      filePath: video.path, animeName: 'Fixture', watchProgress: 0,
      lastPosition: 0, duration: 0, lastWatchTime: DateTime(2026),
    ));
  });

  Future<Response> managed(String method, String route, {String? range}) async =>
    await api.router(Request(method, Uri.parse('http://localhost$route').replace(
      queryParameters: {'path': video.path, if (route == '/subtitle') 'name': 'episode.ass'}),
      headers: {if (range != null) 'range': range}));

  test('explicit managed HEAD retains file length with an empty body', () async {
    final head = await managed('HEAD', '/stream');
    expect(head.statusCode, 200);
    expect(head.contentLength, bytes.length);
    expect(await head.read().toList(), isEmpty);
    final subtitle = await managed('HEAD', '/subtitle');
    expect(subtitle.contentLength, await File('${fixtures.path}/episode.ass').length());
    expect(await subtitle.read().toList(), isEmpty);
  });

  test('managed ranged HEAD and GET describe the same requested bytes', () async {
    final head = await managed('HEAD', '/stream', range: 'bytes=100-199');
    expect(head.statusCode, 206);
    expect(head.contentLength, 100);
    expect(head.headers['content-range'], 'bytes 100-199/4096');
    expect(await head.read().toList(), isEmpty);
    final get = await managed('GET', '/stream', range: 'bytes=100-199');
    expect(await get.read().expand((c) => c).toList(), bytes.sublist(100, 200));
  });

  test('managed suffix ranges return the end, including oversized suffixes', () async {
    for (final count in [32, 8192]) {
      final get = await managed('GET', '/stream', range: 'bytes=-$count');
      expect(get.statusCode, 206);
      expect(await get.read().expand((c) => c).toList(),
        count > bytes.length ? bytes : bytes.sublist(bytes.length - count));
    }
  });

  test('managed unsatisfiable ranges return 416 rather than a negative length', () async {
    for (final range in ['bytes=-0', 'bytes=20-10', 'bytes=4096-', 'bytes=-']) {
      final response = await managed('GET', '/stream', range: range);
      expect(response.statusCode, 416, reason: range);
      expect(response.headers['content-range'], 'bytes */4096');
    }
  });

  test('shared episode stream preserves HEAD metadata and suffix bytes', () async {
    final service = LocalMediaShareService.instance;
    final head = await service.buildStreamResponse(
      Request('HEAD', Uri.parse('http://localhost/stream')), episode, headOnly: true);
    expect(head.contentLength, bytes.length);
    expect(await head.read().toList(), isEmpty);
    final get = await service.buildStreamResponse(
      Request('GET', Uri.parse('http://localhost/stream'), headers: {'range': 'bytes=-32'}), episode);
    expect(get.headers['content-range'], 'bytes 4064-4095/4096');
    expect(await get.read().expand((c) => c).toList(), bytes.sublist(4064));
  });
}

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final base = Uri.parse(args.isEmpty ? 'http://127.0.0.1:1182' : args.first);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  Future<dynamic> json(String path, [Map<String, String>? query]) async {
    final request =
        await client.getUrl(base.replace(path: path, queryParameters: query));
    final response = await request.close().timeout(const Duration(seconds: 90));
    final body = await utf8.decodeStream(response);
    if (response.statusCode != 200)
      throw StateError('$path HTTP ${response.statusCode}');
    return jsonDecode(body);
  }

  final report = <String, dynamic>{};
  for (final account in ['dandanplay', 'bangumi']) {
    final status = await json('/api/$account/login_status');
    report['${account}LoggedIn'] = status['isLoggedIn'];
  }
  final library = await json('/api/media/local/share/animes');
  report['animeCount'] = (library['items'] as List).length;
  final history = await json('/api/history');
  final items = history['data'] as List;
  report['episodeCount'] = items.length;
  if (items.isNotEmpty) {
    final item = items.first;
    final path = item['filePath'] as String;
    final request = await client.getUrl(base.replace(
        path: '/api/media/local/manage/stream',
        queryParameters: {'path': path}));
    request.headers.set('Range', 'bytes=0-1023');
    final response = await request.close();
    final bytes = await response
        .fold<List<int>>([], (buffer, data) => buffer..addAll(data));
  final hostMediaRoot = Platform.environment['NIPAPLAY_HOST_MEDIA_ROOT'];
  if (items.isNotEmpty && (hostMediaRoot == null || hostMediaRoot.isEmpty)) {
    throw StateError('Set NIPAPLAY_HOST_MEDIA_ROOT to the mounted host folder');
  }
  final source = File(path.replaceFirst('/media/anime', hostMediaRoot ?? ''));
    final handle = await source.open();
    final expected = await handle.read(1024);
    await handle.close();
    report['range'] = {
      'status': response.statusCode,
      'contentRange': response.headers.value('content-range'),
      'bytes': bytes.length,
      'matchesSource': base64Encode(bytes) == base64Encode(expected)
    };
  } else {
    report['range'] = {'skipped': 'No registered media in current library'};
  }
  final searchRequest =
      await client.postUrl(base.replace(path: '/api/search/advanced'));
  searchRequest.headers.contentType = ContentType.json;
  searchRequest.write(jsonEncode({'keyword': '惊爆草莓'}));
  final searchResponse =
      await searchRequest.close().timeout(const Duration(seconds: 90));
  final searchBody = await utf8.decodeStream(searchResponse);
  final search = searchResponse.statusCode == 200
      ? jsonDecode(searchBody)
      : <String, dynamic>{};
  report['search'] = {
    'status': searchResponse.statusCode,
    'success': search['success'],
    'results': (search['bangumis'] as List?)?.length
  };
  final comments = await json(
      '/api/danmaku/load', {'animeId': '4223', 'episodeId': '42230001'});
  report['danmakuCount'] = comments is List
      ? comments.length
      : (comments is Map ? (comments['comments'] as List?)?.length : null);
  client.close(force: true);
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

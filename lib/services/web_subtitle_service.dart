import 'dart:convert';
import 'package:http/http.dart' as http;
import 'web_remote_access_service.dart';

/// Transport only: parsing and rendering remain in NipaPlay's subtitle manager.
class WebSubtitleService {
  static bool isAssTrack(Map<String, dynamic> track) {
    final codec = track['codec']?.toString().toLowerCase();
    final name = track['name']?.toString().toLowerCase() ?? '';
    return codec == 'ass' ||
        codec == 'ssa' ||
        name.endsWith('.ass') ||
        name.endsWith('.ssa');
  }

  static Future<Map<String, dynamic>> _get(
      String endpoint, Map<String, String> query) async {
    final base =
        WebRemoteAccessService.apiUri('/api/media/local/manage/$endpoint');
    if (base == null) throw StateError('字幕服务不可用');
    final response = await http
        .get(base.replace(queryParameters: query))
        .timeout(const Duration(seconds: 30));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw StateError(data['message']?.toString() ?? '读取字幕失败');
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> tracks(String path) async =>
      List<Map<String, dynamic>>.from(
          (await _get('web_subtitles', {'path': path}))['items']);

  static Future<List<Map<String, dynamic>>> cues(
          String path, Map<String, dynamic> track) async =>
      List<Map<String, dynamic>>.from((await _get('web_subtitle', {
        'path': path,
        if (track['source'] == 'embedded')
          'index': '${track['index']}'
        else
          'name': track['name'] as String,
      }))['entries']);

  static Future<String> assContent(
      String path, Map<String, dynamic> track) async {
    final base = WebRemoteAccessService.apiUri(
        '/api/media/local/manage/web_subtitle_ass');
    if (base == null) throw StateError('字幕服务不可用');
    final response = await http
        .get(base.replace(queryParameters: {
          'path': path,
          if (track['source'] == 'embedded')
            'index': '${track['index']}'
          else
            'name': track['name'] as String,
        }))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) throw StateError('读取 ASS/SSA 字幕失败');
    return response.body;
  }

  static String cachePath(Map<String, dynamic> track) =>
      'web-subtitle-${track['source']}-${track['index'] ?? track['name']}.srt';
}

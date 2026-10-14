import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';
import 'package:nipaplay/services/web_api_service.dart';
import 'package:nipaplay/utils/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  StorageService.debugAppStorageDirectoryOverride =
      Directory('.porting/account-api-regression')..createSync(recursive: true);
  late WebApiService api;
  setUpAll(() { api = WebApiService(); });
  test('Bangumi token route rejects empty or malformed input before network access', () async {
    for (final body in ['{}', '{"token":" "}', '{"token":123}', 'not-json']) {
      final response = await api.handler(Request('POST',
          Uri.parse('http://localhost/bangumi/login'), body: body));
      expect(response.statusCode, 400);
    }
  });
  test('Bangumi logout and status use the same server account state without credentials', () async {
    final logout = await api.handler(Request('POST', Uri.parse('http://localhost/bangumi/logout')));
    expect(jsonDecode(await logout.readAsString())['success'], true);
    final status = await api.handler(Request('GET', Uri.parse('http://localhost/bangumi/login_status')));
    final data = jsonDecode(await status.readAsString()) as Map;
    expect(data['isLoggedIn'], false);
    expect(data.containsKey('token'), false);
    expect(data.containsKey('accessToken'), false);
  });
}

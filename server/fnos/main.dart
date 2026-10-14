import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:nipaplay/services/server_preferences_store.dart';
import 'package:nipaplay/services/web_api_service.dart';
import 'package:nipaplay/services/dandanplay_service.dart';
import 'package:nipaplay/services/bangumi_sync_service.dart';
import 'package:nipaplay/utils/storage_service.dart';
import 'package:nipaplay/models/watch_history_model.dart';
import 'package:nipaplay/providers/service_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';

/// Runs the existing API in Flutter's headless engine. No runApp, window,
/// desktop session, test framework, or separate business implementation.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final data = Directory(env['NIPAPLAY_DATA_DIR'] ?? '/data').absolute;
  await data.create(recursive: true);
  StorageService.configureServerStorageDirectory(data);
  SharedPreferencesStorePlatform.instance = await ServerPreferencesStore.open(
      File('${data.path}/private/preferences.json'));
  await DandanplayService.initialize();
  await BangumiSyncService.initialize();
  await WatchHistoryManager.initialize();
  await ServiceProvider.scanService.foldersReady;
  ServiceProvider.watchHistoryProvider
      .setScanService(ServiceProvider.scanService);
  await ServiceProvider.watchHistoryProvider.refresh();

  final router = Router()..mount('/api', WebApiService().handler);
  final webRoot = env['NIPAPLAY_WEB_ROOT'];
  final Handler? static = webRoot == null || webRoot.isEmpty
      ? null
      : createStaticHandler(webRoot, defaultDocument: 'index.html');
  final origins = (env['NIPAPLAY_DEV_ORIGINS'] ?? '').split(',').toSet();
  Future<Response> handle(Request req) async {
    final started = DateTime.now();
    final origin = req.headers['origin'];
    final cors = origin != null && origins.contains(origin)
        ? <String, String>{
            'Access-Control-Allow-Origin': origin,
            'Vary': 'Origin',
            'Access-Control-Allow-Methods':
                'GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,Range,Authorization',
            'Access-Control-Expose-Headers':
                'Content-Range,Accept-Ranges,Content-Length'
          }
        : <String, String>{};
    Response result;
    if (req.url.path == 'healthz') {
      result = Response.ok(
          jsonEncode({
            'status': 'ok',
            'app': 'NipaPlay',
            'revision': env['NIPAPLAY_SOURCE_REVISION'],
            'sourceDigest': env['NIPAPLAY_SOURCE_DIGEST'],
            'runtime': 'flutter-headless'
          }),
          headers: {'Content-Type': 'application/json'});
    } else if (req.method == 'OPTIONS' && cors.isNotEmpty) {
      result = Response(204);
    } else if (req.url.path.startsWith('api/remote/')) {
      result = Response(501,
          body: 'Desktop remote control is unavailable in headless mode');
    } else if (req.url.path.startsWith('api/')) {
      result = await router(req);
    } else {
      result = static == null
          ? Response.notFound('API-only development host')
          : await static(req);
    }
    result = result.change(headers: {...cors, 'Cache-Control': 'no-store'});
    // Never log request bodies, query strings, Authorization, or credentials.
    stdout.writeln(
        '${req.method} /${req.url.path} ${result.statusCode} ${DateTime.now().difference(started).inMilliseconds}ms');
    return result;
  }

  final server = await shelf_io.serve(
      handle,
      InternetAddress(env['NIPAPLAY_BIND_ADDRESS'] ?? '127.0.0.1'),
      int.parse(env['NIPAPLAY_PORT'] ?? '1180'));
  stdout.writeln('NipaPlay headless API ready on ${server.port}');
  final stop = Completer<void>();
  final signals = [ProcessSignal.sigterm, ProcessSignal.sigint]
      .map((signal) => signal.watch().listen((_) {
            if (!stop.isCompleted) stop.complete();
          }))
      .toList();
  await stop.future;
  for (final subscription in signals) {
    await subscription.cancel();
  }
  await server.close(force: true);
  exit(0);
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Isolated server storage for existing SharedPreferences business code.
/// Not served by the static Web handler. Requires a single writer process.
class ServerPreferencesStore extends InMemorySharedPreferencesStore {
  ServerPreferencesStore._(this.file, Map<String, Object> data) : super.withData(data);
  final File file;
  Future<void> _pending = Future.value();

  static Future<ServerPreferencesStore> open(File file) async {
    await file.parent.create(recursive: true);
    await _restrict(file.parent.path, '700');
    final data = <String, Object>{};
    if (await file.exists()) {
      await _restrict(file.path, '600');
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final entry in raw.entries) {
        data[entry.key] = entry.value is List
            ? List<String>.from(entry.value) : entry.value as Object;
      }
    }
    return ServerPreferencesStore._(file, data);
  }

  static Future<void> _restrict(String path, String mode) async {
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) throw StateError('Cannot protect server preferences');
  }

  Future<void> _persist() {
    final operation = _pending.then((_) async {
      final temporary = File('${file.path}.pending');
      await temporary.create();
      await _restrict(temporary.path, '600');
      await temporary.writeAsString(jsonEncode(await super.getAll()), flush: true);
      await temporary.rename(file.path);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await super.setValue(valueType, key, value);
    await _persist();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    await super.remove(key);
    await _persist();
    return true;
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    await super.clearWithParameters(parameters);
    await _persist();
    return true;
  }
}

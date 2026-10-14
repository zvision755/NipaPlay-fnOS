import 'dart:convert';
import 'dart:io';

// One-time copy of the original server's data; never edits the source store.
Future<void> main(List<String> args) async {
  if (args.length != 3)
    throw ArgumentError('source-data target-data source-media');
  final source = Directory(args[0]).absolute;
  final target = Directory(args[1]).absolute;
  final media = Directory(args[2]).absolute.path;
  if (await target.exists())
    throw StateError('Snapshot destination already exists');
  await target.create(recursive: true);
  String relocate(String value) =>
      value.replaceAll(media, '/media/anime').replaceAll(source.path, '/data');
  dynamic rewrite(dynamic value) {
    if (value is String) return relocate(value);
    if (value is List) return value.map(rewrite).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(relocate(k.toString()), rewrite(v)));
    return value;
  }

  await for (final item in source.list(recursive: true, followLinks: false)) {
    final relative = item.path.substring(source.path.length + 1);
    if (relative.startsWith('watch_history.db')) continue;
    final destination = '${target.path}/$relative';
    if (item is Directory) {
      await Directory(destination).create(recursive: true);
    } else if (item is File) {
      await File(destination).parent.create(recursive: true);
      if (relative == 'private/preferences.json') {
        final content = rewrite(jsonDecode(await item.readAsString()));
        await File(destination).writeAsString(jsonEncode(content), flush: true);
      } else {
        await item.copy(destination);
      }
    }
  }
  final database = File('${source.path}/watch_history.db');
  if (await database.exists()) {
    final backup = await Process.run('sqlite3',
        [database.path, '.backup "${target.path}/watch_history.db"']);
    if (backup.exitCode != 0) throw StateError('SQLite backup failed');
    String sql(String value) => value.replaceAll("'", "''");
    final update = await Process.run('sqlite3', [
      '${target.path}/watch_history.db',
      "UPDATE watch_history SET file_path=replace(file_path,'${sql(media)}','/media/anime'), "
          "media_key=replace(media_key,'${sql(media)}','/media/anime'), "
          "thumbnail_path=replace(thumbnail_path,'${sql(source.path)}','/data'); PRAGMA integrity_check;"
    ]);
    if (update.exitCode != 0 || update.stdout.toString().trim() != 'ok') {
      throw StateError('Snapshot integrity check failed');
    }
  }
  await Process.run('chmod', ['700', target.path, '${target.path}/private']);
  await Process.run(
      'chmod', ['600', '${target.path}/private/preferences.json']);
  stdout.writeln(
      'Snapshot complete; media paths relocated; SQLite integrity: ok');
}

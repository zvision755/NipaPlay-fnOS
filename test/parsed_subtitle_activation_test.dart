import 'package:flutter_test/flutter_test.dart';
import 'package:nipaplay/player_abstraction/player_abstraction.dart';
import 'package:nipaplay/utils/subtitle_manager.dart';

class _Player extends Fake implements AbstractPlayer {
  @override
  bool get supportsExternalSubtitles => false;
  @override
  List<int> get activeSubtitleTracks => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('decoded subtitle opens, closes and reopens without filesystem access', () {
    final manager = SubtitleManager(player: Player.withDelegate(_Player()));
    const path = 'web-subtitle-embedded-2.srt';
    final cues = <Map<String, dynamic>>[
      {'startTimeMs': 1000, 'endTimeMs': 2000, 'content': '字幕测试'},
    ];
    manager.activateParsedSubtitle(path, cues, displayName: '简体');
    expect(manager.getAllActiveExternalSubtitlePaths(), [path]);
    expect(manager.pathSubtitleTextAt(path, 1500), '字幕测试');
    expect(manager.pathSubtitleTextAt(path, 2500), '');
    manager.clearExternalSubtitle();
    expect(manager.getAllActiveExternalSubtitlePaths(), isEmpty);
    expect(manager.currentExternalSubtitlePath, isNull);
    manager.activateParsedSubtitle(path, cues, displayName: '简体');
    expect(manager.getAllActiveExternalSubtitlePaths(), [path]);
    expect(manager.pathSubtitleTextAt(path, 1500), '字幕测试');
    manager.dispose();
  });
}

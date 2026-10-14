class WebAssSubtitleRenderer {
  static Future<void> attach(String content) async =>
      throw UnsupportedError('ASS 特效字幕仅在 Web 播放器中渲染');
  static Future<void> detach() async {}
}

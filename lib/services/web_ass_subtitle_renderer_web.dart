import 'dart:html' as html;
import 'dart:js_util' as js_util;

class WebAssSubtitleRenderer {
  static Future<void> attach(String content) async {
    final video = html.document.querySelector('video');
    if (video == null) throw StateError('找不到浏览器视频画面');
    await js_util.promiseToFuture<void>(
        js_util.getProperty<Object>(html.window, 'nipaPlayAssReady'));
    await js_util.promiseToFuture<void>(js_util.callMethod<Object>(
        html.window, 'nipaPlayAssAttach', <Object>[video, content]));
  }

  static Future<void> detach() async {
    final detach =
        js_util.getProperty<Object?>(html.window, 'nipaPlayAssDetach');
    if (detach == null) return;
    await js_util.promiseToFuture<void>(
        js_util.callMethod<Object>(html.window, 'nipaPlayAssDetach', const []));
  }
}

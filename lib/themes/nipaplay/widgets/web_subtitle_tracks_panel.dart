import 'package:flutter/material.dart';
import 'package:nipaplay/services/web_subtitle_service.dart';
import 'package:nipaplay/utils/subtitle_language_utils.dart';
import 'package:nipaplay/utils/video_player_state.dart';
import 'base_settings_menu.dart';
import 'blur_button.dart';

/// Web transport adapter for the original subtitle menu and text overlay.
class WebSubtitleTracksPanel extends StatefulWidget {
  final VideoPlayerState videoState;
  final VoidCallback onClose;
  final ValueChanged<bool>? onHoverChanged;
  const WebSubtitleTracksPanel(
      {super.key,
      required this.videoState,
      required this.onClose,
      this.onHoverChanged});
  @override
  State<WebSubtitleTracksPanel> createState() => _WebSubtitleTracksPanelState();
}

class _WebSubtitleTracksPanelState extends State<WebSubtitleTracksPanel> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  String? _error;
  String? get _sourcePath =>
      Uri.tryParse(widget.videoState.currentVideoPath ?? '')
          ?.queryParameters['path'];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = _sourcePath;
      if (path == null) throw StateError('当前媒体源尚未提供 Web 字幕接口');
      final tracks = await WebSubtitleService.tracks(path);
      if (mounted)
        setState(() {
          _tracks = tracks;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate(Map<String, dynamic> track) async {
    final videoPath = widget.videoState.currentVideoPath;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!mounted || videoPath != widget.videoState.currentVideoPath) return;
      if (videoPath == null) return;
      await widget.videoState.subtitleManager
          .activateWebSubtitleTrack(videoPath, track);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => BaseSettingsMenu(
        title: '字幕轨道',
        onClose: widget.onClose,
        onHoverChanged: widget.onHoverChanged,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          BlurButton(
              text: '关闭字幕',
              icon: Icons.subtitles_off,
              onTap: () {
                widget.videoState.disableWebSubtitle();
                setState(() {});
              }),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator()),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (!_loading && _tracks.isEmpty && _error == null)
            const Text('没有找到可用字幕'),
          for (final track in _tracks)
            BlurButton(
                text:
                    '${track['source'] == 'embedded' ? '内封字幕' : '外挂字幕'}：${getSubtitleLanguageName(track['name'].toString())}',
                icon: Icons.subtitles,
                onTap: () {
                  if (!_loading) _activate(track);
                }),
        ]),
      );
}

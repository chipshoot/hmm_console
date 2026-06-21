import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Journal-style audio card: play/pause + elapsed/total + a seekable slider.
/// [resolvePath] returns a local playable file path (resolved lazily on first
/// play so the card renders instantly).
class NoteAudioCard extends StatefulWidget {
  const NoteAudioCard({
    super.key,
    required this.name,
    required this.resolvePath,
    this.onRemove,
    this.readOnly = false,
  });

  final String name;
  final Future<String> Function() resolvePath;
  final VoidCallback? onRemove;
  final bool readOnly;

  @override
  State<NoteAudioCard> createState() => _NoteAudioCardState();
}

class _NoteAudioCardState extends State<NoteAudioCard> {
  AudioPlayer? _player;
  bool _loading = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer> _ensure() async {
    if (_player != null) return _player!;
    final player = AudioPlayer();
    final path = await widget.resolvePath();
    await player.setFilePath(path);
    _player = player;
    return player;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final player = await _ensure();
      if (player.playing) {
        await player.pause();
      } else {
        if (player.position >= (player.duration ?? Duration.zero)) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      // Playback failure → leave the card in a non-playing state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = _player;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                (player?.playing ?? false) ? Icons.pause : Icons.play_arrow),
            onPressed: _toggle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
                if (player != null)
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final total = player.duration ?? Duration.zero;
                      final max = total.inMilliseconds.toDouble();
                      return Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: pos.inMilliseconds
                                  .clamp(0, max == 0 ? 1 : max.toInt())
                                  .toDouble(),
                              max: max == 0 ? 1 : max,
                              onChanged: (v) => player
                                  .seek(Duration(milliseconds: v.toInt())),
                            ),
                          ),
                          Text('${_fmt(pos)} / ${_fmt(total)}',
                              style: theme.textTheme.bodySmall),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          if (!widget.readOnly && widget.onRemove != null)
            GestureDetector(
              onTap: widget.onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 18)),
            ),
        ],
      ),
    );
  }
}

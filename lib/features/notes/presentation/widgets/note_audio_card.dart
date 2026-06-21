import 'dart:async';

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
  bool _preparing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player != null) {
      // Live player: toggle. Do NOT await play() — just_audio's play()
      // future completes only when playback ENDS, which would block pause.
      if (player.playing) {
        unawaited(player.pause());
      } else {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        unawaited(player.play());
      }
      return;
    }
    // First play: create + load (the only genuinely async setup), then start.
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      final created = AudioPlayer();
      final path = await widget.resolvePath();
      await created.setFilePath(path);
      if (!mounted) {
        await created.dispose();
        return;
      }
      _player = created;
      unawaited(created.play());
    } catch (_) {
      // resolve/load failure → nothing playable; leave the card idle.
    } finally {
      if (mounted) setState(() => _preparing = false);
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
          if (player == null)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _preparing ? null : _toggle,
            )
          else
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snap) {
                final state = snap.data;
                final showPause = (state?.playing ?? false) &&
                    state?.processingState != ProcessingState.completed;
                return IconButton(
                  icon: Icon(showPause ? Icons.pause : Icons.play_arrow),
                  onPressed: _toggle,
                );
              },
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

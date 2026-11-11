import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import '../../../../core/widgets/adaptive_icon.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/hmm_icon_button.dart';

/// The search box: free text, with the active token chips under it.
///
/// The query lives on the notifier so it survives reactive data emissions —
/// and therefore also survives leaving the screen. With an uncontrolled
/// TextField that meant coming back to an empty-looking box silently filtering
/// the list, which reads as "all my notes are gone". So [text] is the applied
/// text and is copied into the box when it changes from elsewhere.
///
/// Typing is debounced: the text is sent 150 ms after the last keystroke, so a
/// fast typist does not re-run the search per letter.
///
/// The chips are built by the screen. On a hardware keyboard, Backspace in an
/// empty box calls [onRemoveLastToken]; on-screen keyboards use the chip's ✕.
class NoteSearchField extends StatefulWidget {
  const NoteSearchField({
    super.key,
    required this.text,
    required this.chips,
    required this.hintText,
    required this.clearTooltip,
    required this.onTextChanged,
    required this.onRemoveLastToken,
    this.onSubmitted,
    this.focusNode,
  });

  /// The applied text (from the notifier).
  final String text;
  final List<Widget> chips;
  final String hintText;
  final String clearTooltip;

  /// Debounced 150 ms.
  final ValueChanged<String> onTextChanged;

  /// Hardware Backspace on empty text.
  final VoidCallback onRemoveLastToken;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<NoteSearchField> createState() => NoteSearchFieldState();
}

class NoteSearchFieldState extends State<NoteSearchField> {
  static const _debounce = Duration(milliseconds: 150);

  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  )..addListener(_onControllerChanged);
  late String _lastSent;
  late bool _hasText;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Eager, not `late` initialisers: those would first run inside
    // didUpdateWidget, after widget.text had already moved on.
    _lastSent = widget.text;
    _hasText = widget.text.isNotEmpty;
  }

  void _onControllerChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _send(String text) {
    _timer?.cancel();
    _lastSent = text;
    widget.onTextChanged(text);
  }

  void _onTyped(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _send(text));
  }

  void _clear() {
    _controller.clear();
    _send('');
  }

  /// Empties the box and drops any pending keystroke without sending. Used
  /// when a suggestion turns the typed text into a token: the text must not
  /// arrive a moment later and undo it.
  void clearAndCancel() {
    _timer?.cancel();
    _lastSent = '';
    _controller.clear();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty) {
      widget.onRemoveLastToken();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant NoteSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a change made elsewhere (e.g. "Clear search" in the empty state)
    // is copied into the box. Echoes of what this field sent, and rebuilds
    // while a keystroke is still pending, must not move the caret or undo
    // the typing.
    if (widget.text != oldWidget.text &&
        widget.text != _lastSent &&
        widget.text != _controller.text) {
      _timer?.cancel();
      _lastSent = widget.text;
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          onKeyEvent: _onKey,
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              prefixIcon: Icon(
                adaptiveIcon(
                  context,
                  material: Icons.search,
                  apple: CupertinoIcons.search,
                ),
              ),
              hintText: widget.hintText,
              isDense: true,
              border: const OutlineInputBorder(),
              // A way out that does not require selecting invisible text.
              suffixIcon: _hasText
                  ? HmmIconButton(
                      key: const Key('notesSearchClear'),
                      icon: adaptiveIcon(
                        context,
                        material: Icons.clear,
                        apple: CupertinoIcons.xmark_circle_fill,
                      ),
                      tooltip: widget.clearTooltip,
                      onPressed: _clear,
                    )
                  : null,
            ),
            onChanged: _onTyped,
            onSubmitted: (text) {
              _send(text);
              widget.onSubmitted?.call(text);
            },
          ),
        ),
        if (widget.chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 4, children: widget.chips),
          ),
      ],
    );
  }
}

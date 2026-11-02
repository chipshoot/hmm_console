import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/search_normalize.dart';
import '../../query/markdown_text.dart';

enum PreviewStyle { plain, bold, italic, boldItalic, code, link }

typedef PreviewRun = ({String text, PreviewStyle style});

const _skipped = {'img', 'table', 'pre', 'hr'};
const _containers = {'ul', 'ol', 'li', 'blockquote'};
const _blocks = {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

/// How much of a note the row preview parses: far more than a preview
/// shows, so a long note costs no more than a short one.
const previewSourceLimit = 4000;

/// A line-break cut must keep at least this much: a full preview (the
/// default `maxChars` of [previewRuns]).
const _minLineCut = 400;

/// The first [previewSourceLimit] characters of [markdown], cut after the
/// last line break inside them when that keeps at least [_minLineCut]
/// characters, never inside a surrogate pair.
String boundedPreviewSource(String markdown) {
  if (markdown.length <= previewSourceLimit) return markdown;
  final newline = markdown.lastIndexOf('\n', previewSourceLimit - 1);
  if (newline + 1 >= _minLineCut) return markdown.substring(0, newline + 1);
  var end = previewSourceLimit;
  final last = markdown.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end++; // keep the pair whole
  return markdown.substring(0, end);
}

/// Styled runs of [markdown] for a row preview: no raw markers, list items
/// prefixed `• ` (tasks `☐ `/`☑ `), images/tables/HTML/fenced code omitted,
/// blocks separated by one space, stopping after [maxChars] characters. Only
/// [boundedPreviewSource] of it is parsed.
List<PreviewRun> previewRuns(String markdown, {int maxChars = 400}) {
  if (markdown.isEmpty) return const [];
  final b = _RunBuilder(maxChars);
  // Top-level Text nodes are raw HTML blocks, so they are skipped.
  _blockWalk(parseMarkdownNodes(boundedPreviewSource(markdown)), b, root: true);
  return b.runs;
}

/// The concatenated text of [runs].
String previewPlain(List<PreviewRun> runs) => runs.map((r) => r.text).join();

class _RunBuilder {
  _RunBuilder(this.maxChars);
  final int maxChars;
  final runs = <PreviewRun>[];
  int _length = 0;
  bool _pendingSpace = false;

  bool get full => _length >= maxChars;

  void blockBreak() => _pendingSpace = true;

  void add(String raw, PreviewStyle style) {
    if (full) return;
    var text = raw.replaceAll(RegExp(r'\s*\n\s*'), ' ');
    final atBoundary = runs.isEmpty || runs.last.text.endsWith(' ');
    if (atBoundary) text = text.trimLeft();
    if (text.isEmpty) return;
    if (_pendingSpace && !atBoundary) _emit(' ', PreviewStyle.plain);
    _pendingSpace = false;
    _emit(text, style);
  }

  void _emit(String raw, PreviewStyle style) {
    var text = raw;
    if (_length + text.length > maxChars) {
      text = text.substring(0, maxChars - _length);
    }
    if (text.isEmpty) return;
    _length += text.length;
    runs.add((text: text, style: style));
  }
}

void _blockWalk(List<md.Node> nodes, _RunBuilder b, {bool root = false}) {
  for (final n in nodes) {
    if (b.full) return;
    if (n is md.Text) {
      if (!root) _inlineWalk(n, b, const _Flags());
    } else if (n is md.Element) {
      if (_skipped.contains(n.tag) || n.tag == 'input') continue;
      if (n.tag == 'li') {
        _listItem(n, b);
      } else if (_containers.contains(n.tag)) {
        b.blockBreak();
        _blockWalk(n.children ?? const [], b);
        b.blockBreak();
      } else if (_blocks.contains(n.tag)) {
        b.blockBreak();
        _inlineWalk(n, b, _Flags(heading: n.tag.startsWith('h')));
        b.blockBreak();
      } else {
        _inlineWalk(n, b, const _Flags());
      }
    }
  }
}

void _listItem(md.Element li, _RunBuilder b) {
  final children = li.children ?? const <md.Node>[];
  // Tight lists put the checkbox first in the li; loose lists wrap the
  // content in a <p>, so it is the first child of that paragraph.
  md.Node? first = children.isEmpty ? null : children.first;
  if (first is md.Element && first.tag == 'p') {
    final inner = first.children;
    first = inner == null || inner.isEmpty ? null : inner.first;
  }
  final box = first is md.Element && first.tag == 'input' ? first : null;
  b.blockBreak();
  if (box != null) {
    final checked = box.attributes.containsKey('checked');
    b.add(checked ? '☑ ' : '☐ ', PreviewStyle.plain);
  } else {
    b.add('• ', PreviewStyle.plain);
  }
  // The input element itself is skipped by both walkers.
  _blockWalk(children, b);
  b.blockBreak();
}

class _Flags {
  const _Flags({
    this.heading = false,
    this.strong = false,
    this.em = false,
    this.code = false,
    this.link = false,
  });
  final bool heading, strong, em, code, link;

  _Flags copy({bool? strong, bool? em, bool? code, bool? link}) => _Flags(
    heading: heading,
    strong: strong ?? this.strong,
    em: em ?? this.em,
    code: code ?? this.code,
    link: link ?? this.link,
  );

  PreviewStyle get style {
    if (code) return PreviewStyle.code;
    if (link) return PreviewStyle.link;
    final bold = strong || heading;
    if (bold && em) return PreviewStyle.boldItalic;
    if (bold) return PreviewStyle.bold;
    if (em) return PreviewStyle.italic;
    return PreviewStyle.plain;
  }
}

void _inlineWalk(md.Node n, _RunBuilder b, _Flags f) {
  if (b.full) return;
  if (n is md.Text) {
    b.add(n.text, f.style);
  } else if (n is md.Element) {
    if (_skipped.contains(n.tag) || n.tag == 'input') return;
    if (n.tag == 'br') {
      b.add(' ', PreviewStyle.plain);
      return;
    }
    final next = switch (n.tag) {
      'strong' => f.copy(strong: true),
      'em' => f.copy(em: true),
      'code' => f.copy(code: true),
      'a' => f.copy(link: true),
      _ => f,
    };
    for (final c in n.children ?? const <md.Node>[]) {
      _inlineWalk(c, b, next);
    }
  }
}

/// A row's note preview: pre-computed [runs] (see [previewRuns]; a single
/// plain run for entity notes) clamped to [maxLines], with [highlightWords]
/// marked.
class NotePreviewText extends StatelessWidget {
  const NotePreviewText({
    super.key,
    required this.runs,
    required this.maxLines,
    this.highlightWords = const [],
  });

  final List<PreviewRun> runs;
  final int maxLines;
  final List<String> highlightWords;

  @override
  Widget build(BuildContext context) {
    final ranges = _matchRanges(previewPlain(runs), highlightWords);
    final base = DefaultTextStyle.of(context).style;
    final accent = context.appColors.accent;
    final hit = accent.withValues(alpha: 0.25);

    final spans = <InlineSpan>[];
    var offset = 0;
    for (final run in runs) {
      final style = _styleFor(run.style, base, accent);
      final end = offset + run.text.length;
      var cursor = offset;
      void emit(int from, int to, bool highlighted) {
        if (to <= from) return;
        spans.add(
          TextSpan(
            text: run.text.substring(from - offset, to - offset),
            style: highlighted ? style.copyWith(backgroundColor: hit) : style,
          ),
        );
      }

      for (final r in ranges) {
        if (r.end <= cursor || r.start >= end) continue;
        final s = r.start < cursor ? cursor : r.start;
        final e = r.end > end ? end : r.end;
        emit(cursor, s, false);
        emit(s, e, true);
        cursor = e;
      }
      emit(cursor, end, false);
      offset = end;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

TextStyle _styleFor(PreviewStyle s, TextStyle base, Color accent) =>
    switch (s) {
      PreviewStyle.plain => base,
      PreviewStyle.bold => base.copyWith(fontWeight: FontWeight.w600),
      PreviewStyle.italic => base.copyWith(fontStyle: FontStyle.italic),
      PreviewStyle.boldItalic => base.copyWith(
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      ),
      PreviewStyle.code => base.copyWith(fontFamily: 'monospace'),
      PreviewStyle.link => base.copyWith(color: accent),
    };

/// Merged, sorted `[start, end)` occurrences of every word in [text]
/// (accent/case-insensitive; folding preserves length so offsets carry over).
List<({int start, int end})> _matchRanges(String text, List<String> words) {
  if (text.isEmpty || words.isEmpty) return const [];
  final folded = foldForMatch(text);
  final found = <({int start, int end})>[];
  for (final w in words) {
    final needle = foldForMatch(w);
    if (needle.isEmpty) continue;
    var i = folded.indexOf(needle);
    while (i >= 0) {
      found.add((start: i, end: i + needle.length));
      i = folded.indexOf(needle, i + needle.length);
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));
  final merged = <({int start, int end})>[];
  for (final r in found) {
    if (merged.isNotEmpty && r.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: r.end > last.end ? r.end : last.end));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

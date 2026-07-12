// The single place the markdown rendering package is referenced. `MarkdownView`
// now lives in `note_markdown_body.dart` (it resolves inline `hmm-attachment://`
// images); this file re-exports it so existing `MarkdownView(markdown)` call
// sites keep working.
export 'note_markdown_body.dart' show MarkdownView, NoteMarkdownBody;

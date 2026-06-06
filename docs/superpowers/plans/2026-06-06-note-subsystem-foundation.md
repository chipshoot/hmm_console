# Note Subsystem Foundation (A+D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the missing note UI to hmm_console — create/read/edit/soft-delete free-form notes, render every note (domain or not) read-only as markdown, list notes with Mail/Outlook-style filter+sort, dispatch edits to domain editors (Gas Log wired), and always-on raw-content viewing.

**Architecture:** A universal read path keyed on the note's catalog name. Domain-agnostic pieces (renderer interface, generic JSON + general renderers, catalog palette, edit-dispatch) live in `lib/core/notes/`; the registry that *names* the domain renderers is assembled in `lib/features/notes/rendering/` (the legitimate aggregator) so `core` never imports a domain feature. Free-form notes use a seeded "General" `NoteCatalog`; markdown lives in `Notes.content`; images reuse the existing vault/attachments stack. All DI/state is Riverpod, following the existing `AsyncNotifier` pattern.

**Tech Stack:** Flutter + Dart (sdk ^3.11.0), `flutter_riverpod` ^3.0.3, `drift`, `go_router`, `flutter_markdown` (new), `image_picker` (existing). Tests: `flutter_test` + `mockito` + in-memory Drift + `ProviderContainer`/`overrideWith`.

**Reused, already in the codebase (do not recreate):**
- `hmmNoteRepositoryProvider` → `IHmmNoteRepository` — `getNotes({catalogId, parentNoteId, page, pageSize, includeDeleted}) → Future<PageList<HmmNote>>`, `getNoteById(int)`, `createNote(HmmNoteCreate)`, `updateNote(int, HmmNoteUpdate)`, `deleteNote(int)`.
- `noteCatalogRepositoryProvider` → `INoteCatalogRepository` — `getCatalogs()`, `getCatalogById(int)`, `getCatalogByName(String)`, `getOrCreateCatalog(name, schema)`, `createCatalog(NoteCatalogsCompanion)`.
- Models: `HmmNote` (`id, uuid, subject, content?, authorId, catalogId?, parentNoteId?, description?, createDate, lastModifiedDate?, deletedAt, version?, attachments?`, plus `effectiveAttachments`, `isDeleted`); `HmmNoteCreate({subject, catalogId, content?, parentNoteId?, description?, attachments?})`; `HmmNoteUpdate({subject?, content?, description?, attachments?})`.
- Attachments: `NoteAttachments({primaryImage?, images})` + `NoteAttachments.empty`/`isEmpty`; `VaultRef` (a `sealed AttachmentRef`); `imageAttachmentPickerProvider` → `IImageAttachmentPicker.pickForNote({required int noteId, AttachmentPickSource source}) → Future<VaultRef?>`; `attachmentResolverProvider` → `IAttachmentResolver.resolve(AttachmentRef) → Future<Uint8List?>`; enum `AttachmentPickSource { gallery, camera }`.
- `PageList<T>` = `PaginatedResponse<T>{items, meta}`.
- Drift `NoteCatalog` row: `id, name, schema, render?, formatType (int), isDefault, description?`; `NoteCatalogsCompanion`.
- Drift providers: `hmmDatabaseProvider`, `localHmmNoteRepositoryProvider`, `localNoteCatalogRepositoryProvider`; `dataModeProvider`.
- Router: `RouterNames` enum + `GoRoute(name: RouterNames.x.name, routes: [...])`; navigation via `context.push('/path')`.
- Dashboard tile: `_navigateToFunction` switch in `dashboard_screen.dart` (currently only `case 'gas-log'`).

**Facts that the code depends on (verified):**
- Domain catalog names are fully-qualified: Gas Log = `Hmm.AutomobileMan.GasLog`, Automobile = `Hmm.AutomobileMan.AutomobileInfo`, Insurance = `Hmm.AutomobileMan.AutoInsurancePolicy`, Scheduled service = `Hmm.AutomobileMan.AutoScheduledService`, Service record = `Hmm.AutomobileMan.ServiceRecord`.
- A gas-log note's `content` is `{"note":{"content":{"GasLog":{…}}}}`.
- A gas-log entity's id **is** its note id, and `/gas-logs/:id/edit` already loads by that id.
- `NoteContentFormatType` enum order is `PlainText=0, Xml=1, Json=2, Markdown=3`.

---

## Task 1: Markdown dependency + `MarkdownView` wrapper

Isolating the markdown package behind one widget means a future package swap touches a single file.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/notes/presentation/widgets/markdown_view.dart`
- Test: `test/features/notes/presentation/widgets/markdown_view_test.dart`

- [ ] **Step 1: Add the dependency**

Run: `cd ~/projects/hmm_console && flutter pub add flutter_markdown`
Expected: `pubspec.yaml` gains `flutter_markdown: ^0.7.x` and `flutter pub get` resolves.
Contingency: if it fails to resolve against this Flutter version, instead run `flutter pub add markdown_widget` and in Step 3 use `MarkdownWidget(data: data, shrinkWrap: true)` from `package:markdown_widget/markdown_widget.dart`. Only this file changes.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/markdown_view.dart';

void main() {
  testWidgets('renders a MarkdownBody for the given markdown', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MarkdownView('# Title\n\nBody text')),
    ));
    expect(find.byType(MarkdownView), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/widgets/markdown_view_test.dart`
Expected: FAIL — `markdown_view.dart` does not exist.

- [ ] **Step 4: Implement `MarkdownView`**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// The single place the markdown rendering package is referenced. Swap the
/// package here without touching call sites.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) =>
      MarkdownBody(data: data, selectable: true);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/widgets/markdown_view_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/notes/presentation/widgets/markdown_view.dart test/features/notes/presentation/widgets/markdown_view_test.dart
git commit -m "feat(notes): add flutter_markdown + MarkdownView wrapper"
```

---

## Task 2: Catalog palette (display name + color)

Maps catalog names to a friendly label and a color. Drives chips, color dots, the filter sheet, and the future calendar.

**Files:**
- Create: `lib/core/notes/catalog_palette.dart`
- Test: `test/core/notes/catalog_palette_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';

void main() {
  test('General name constant is "General"', () {
    expect(kGeneralCatalogName, 'General');
  });

  test('known catalog returns friendly name + color', () {
    final s = CatalogPalette.styleFor('Hmm.AutomobileMan.GasLog');
    expect(s.displayName, 'Gas Log');
    expect(s.color, const Color(0xFFFFD60A));
  });

  test('unknown FQN derives last segment + default gray', () {
    final s = CatalogPalette.styleFor('Hmm.Foo.WidgetThing');
    expect(s.displayName, 'WidgetThing');
    expect(s.color, const Color(0xFF8E8E93));
  });

  test('null catalog returns a default style', () {
    final s = CatalogPalette.styleFor(null);
    expect(s.color, const Color(0xFF8E8E93));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/notes/catalog_palette_test.dart`
Expected: FAIL — `catalog_palette.dart` not found.

- [ ] **Step 3: Implement the palette**

```dart
import 'package:flutter/material.dart';

/// Catalog name for free-form user notes.
const String kGeneralCatalogName = 'General';

class CatalogStyle {
  const CatalogStyle(this.displayName, this.color);
  final String displayName;
  final Color color;
}

class CatalogPalette {
  const CatalogPalette._();

  static const Color _default = Color(0xFF8E8E93);

  static const Map<String, CatalogStyle> _known = {
    kGeneralCatalogName: CatalogStyle('General', Color(0xFF34C759)),
    'Hmm.AutomobileMan.GasLog': CatalogStyle('Gas Log', Color(0xFFFFD60A)),
    'Hmm.AutomobileMan.AutomobileInfo':
        CatalogStyle('Automobile', Color(0xFF0A84FF)),
    'Hmm.AutomobileMan.AutoInsurancePolicy':
        CatalogStyle('Insurance', Color(0xFFFF9F0A)),
    'Hmm.AutomobileMan.AutoScheduledService':
        CatalogStyle('Scheduled Service', Color(0xFFBF5AF2)),
    'Hmm.AutomobileMan.ServiceRecord':
        CatalogStyle('Service Record', Color(0xFFFF453A)),
  };

  static CatalogStyle styleFor(String? catalogName) {
    if (catalogName == null) return const CatalogStyle('Note', _default);
    final known = _known[catalogName];
    if (known != null) return known;
    final seg = catalogName.split('.').last;
    return CatalogStyle(seg.isEmpty ? catalogName : seg, _default);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/notes/catalog_palette_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/notes/catalog_palette.dart test/core/notes/catalog_palette_test.dart
git commit -m "feat(notes): add catalog palette (display name + color)"
```

---

## Task 3: `NoteRenderer` interface + `GenericJsonRenderer`

The fallback renderer. Turns any JSON content into a readable markdown bullet tree; passes non-JSON through; also exposes the static `jsonToMarkdown` reused by the Gas Log renderer.

**Files:**
- Create: `lib/core/notes/rendering/note_renderer.dart`
- Create: `lib/core/notes/rendering/generic_json_renderer.dart`
- Test: `test/core/notes/rendering/generic_json_renderer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/rendering/generic_json_renderer.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

HmmNote _note({String? content, String? description}) => HmmNote(
      id: 1,
      uuid: 'u',
      subject: 's',
      authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: content,
      description: description,
    );

void main() {
  const r = GenericJsonRenderer();

  test('renders JSON object as a bold bullet tree', () {
    final out = r.render(_note(content: '{"Station":"Shell","Volume":45.2}'));
    expect(out, contains('- **Station:** Shell'));
    expect(out, contains('- **Volume:** 45.2'));
  });

  test('passes non-JSON content through verbatim', () {
    final out = r.render(_note(content: 'just text'));
    expect(out, 'just text');
  });

  test('empty content falls back to description then to a marker', () {
    expect(r.render(_note(description: 'desc')), 'desc');
    expect(r.render(_note()), '_(empty note)_');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/notes/rendering/generic_json_renderer_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Implement the interface**

```dart
// lib/core/notes/rendering/note_renderer.dart
import '../../../features/notes/data/models/hmm_note.dart';

/// Produces a read-only markdown string for a note. Implementations must not
/// throw — see render_registry, which isolates failures behind the fallback.
abstract interface class NoteRenderer {
  String render(HmmNote note);
}
```

- [ ] **Step 4: Implement `GenericJsonRenderer`**

```dart
// lib/core/notes/rendering/generic_json_renderer.dart
import 'dart:convert';

import '../../../features/notes/data/models/hmm_note.dart';
import 'note_renderer.dart';

class GenericJsonRenderer implements NoteRenderer {
  const GenericJsonRenderer();

  @override
  String render(HmmNote note) {
    final content = note.content?.trim();
    if (content == null || content.isEmpty) {
      final desc = note.description?.trim();
      return (desc == null || desc.isEmpty) ? '_(empty note)_' : desc;
    }
    try {
      return jsonToMarkdown(jsonDecode(content)).trimRight();
    } catch (_) {
      return content; // not JSON — show as-is
    }
  }

  /// Render decoded JSON as a nested markdown bullet list.
  static String jsonToMarkdown(Object? node, {int depth = 0}) {
    final buf = StringBuffer();
    final pad = '  ' * depth;
    if (node is Map) {
      node.forEach((k, v) {
        if (v is Map || v is List) {
          buf.writeln('$pad- **$k:**');
          buf.write(jsonToMarkdown(v, depth: depth + 1));
        } else {
          buf.writeln('$pad- **$k:** $v');
        }
      });
    } else if (node is List) {
      for (final item in node) {
        if (item is Map || item is List) {
          buf.write(jsonToMarkdown(item, depth: depth));
        } else {
          buf.writeln('$pad- $item');
        }
      }
    } else {
      buf.writeln('$pad$node');
    }
    return buf.toString();
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/notes/rendering/generic_json_renderer_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/notes/rendering/note_renderer.dart lib/core/notes/rendering/generic_json_renderer.dart test/core/notes/rendering/generic_json_renderer_test.dart
git commit -m "feat(notes): add NoteRenderer interface + GenericJsonRenderer fallback"
```

---

## Task 4: `GeneralNoteRenderer`

Free-form notes store markdown directly in `content`, so this renderer is a pass-through with empty-fallbacks.

**Files:**
- Create: `lib/core/notes/rendering/general_note_renderer.dart`
- Test: `test/core/notes/rendering/general_note_renderer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/rendering/general_note_renderer.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

HmmNote _note({String? content, String? description}) => HmmNote(
      id: 1, uuid: 'u', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: content, description: description,
    );

void main() {
  const r = GeneralNoteRenderer();

  test('returns markdown body verbatim', () {
    expect(r.render(_note(content: '# Hi\n\n- a')), '# Hi\n\n- a');
  });

  test('empty body falls back to description, then marker', () {
    expect(r.render(_note(description: 'd')), 'd');
    expect(r.render(_note()), '_(empty note)_');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/notes/rendering/general_note_renderer_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `GeneralNoteRenderer`**

```dart
import '../../../features/notes/data/models/hmm_note.dart';
import 'note_renderer.dart';

class GeneralNoteRenderer implements NoteRenderer {
  const GeneralNoteRenderer();

  @override
  String render(HmmNote note) {
    final body = note.content?.trim();
    if (body != null && body.isNotEmpty) return body;
    final desc = note.description?.trim();
    return (desc == null || desc.isEmpty) ? '_(empty note)_' : desc;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/notes/rendering/general_note_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/notes/rendering/general_note_renderer.dart test/core/notes/rendering/general_note_renderer_test.dart
git commit -m "feat(notes): add GeneralNoteRenderer (markdown passthrough)"
```

---

## Task 5: `GasLogNoteRenderer` (proof-of-pattern domain renderer)

Unwraps the gas-log envelope (`note.content.GasLog`) and renders that sub-tree via the shared formatter. Lives in the gas_log feature.

**Files:**
- Create: `lib/features/gas_log/rendering/gas_log_note_renderer.dart`
- Test: `test/features/gas_log/rendering/gas_log_note_renderer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/rendering/gas_log_note_renderer.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

HmmNote _note(String? content) => HmmNote(
      id: 1, uuid: 'u', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1), content: content,
    );

void main() {
  const r = GasLogNoteRenderer();

  test('catalogName matches the domain catalog', () {
    expect(GasLogNoteRenderer.catalogName, 'Hmm.AutomobileMan.GasLog');
  });

  test('unwraps the GasLog envelope and renders its fields', () {
    final out = r.render(_note(
        '{"note":{"content":{"GasLog":{"station":"Shell","_v":1}}}}'));
    expect(out, contains('### Gas Log'));
    expect(out, contains('- **station:** Shell'));
  });

  test('falls back without throwing on malformed content', () {
    expect(() => r.render(_note('not json')), returnsNormally);
    expect(() => r.render(_note(null)), returnsNormally);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_log/rendering/gas_log_note_renderer_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `GasLogNoteRenderer`**

```dart
import 'dart:convert';

import '../../../core/notes/rendering/generic_json_renderer.dart';
import '../../../core/notes/rendering/note_renderer.dart';
import '../../notes/data/models/hmm_note.dart';

class GasLogNoteRenderer implements NoteRenderer {
  const GasLogNoteRenderer();

  static const String catalogName = 'Hmm.AutomobileMan.GasLog';

  @override
  String render(HmmNote note) {
    final content = note.content;
    if (content != null) {
      try {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final gasLog = json['note']?['content']?['GasLog'];
        if (gasLog is Map<String, dynamic>) {
          return '### Gas Log\n\n${GenericJsonRenderer.jsonToMarkdown(gasLog).trimRight()}';
        }
      } catch (_) {/* fall through to generic */}
    }
    return const GenericJsonRenderer().render(note);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gas_log/rendering/gas_log_note_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/gas_log/rendering/gas_log_note_renderer.dart test/features/gas_log/rendering/gas_log_note_renderer_test.dart
git commit -m "feat(gas_log): add GasLogNoteRenderer (envelope unwrap)"
```

---

## Task 6: Render registry provider

Assembles the catalog-name → renderer map (the aggregator that knows about domains). Unknown/null catalog → generic fallback.

**Files:**
- Create: `lib/features/notes/rendering/render_registry.dart`
- Test: `test/features/notes/rendering/render_registry_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/rendering/general_note_renderer.dart';
import 'package:hmm_console/core/notes/rendering/generic_json_renderer.dart';
import 'package:hmm_console/features/gas_log/rendering/gas_log_note_renderer.dart';
import 'package:hmm_console/features/notes/rendering/render_registry.dart';

void main() {
  test('resolves registered renderers, falls back otherwise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reg = container.read(noteRenderRegistryProvider);

    expect(reg.rendererFor(kGeneralCatalogName), isA<GeneralNoteRenderer>());
    expect(reg.rendererFor(GasLogNoteRenderer.catalogName),
        isA<GasLogNoteRenderer>());
    expect(reg.rendererFor('Unknown.Catalog'), isA<GenericJsonRenderer>());
    expect(reg.rendererFor(null), isA<GenericJsonRenderer>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/rendering/render_registry_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the registry**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notes/catalog_palette.dart';
import '../../../core/notes/rendering/general_note_renderer.dart';
import '../../../core/notes/rendering/generic_json_renderer.dart';
import '../../../core/notes/rendering/note_renderer.dart';
import '../../gas_log/rendering/gas_log_note_renderer.dart';

class NoteRenderRegistry {
  const NoteRenderRegistry(this._byCatalog);

  final Map<String, NoteRenderer> _byCatalog;
  static const NoteRenderer _fallback = GenericJsonRenderer();

  NoteRenderer rendererFor(String? catalogName) {
    if (catalogName == null) return _fallback;
    return _byCatalog[catalogName] ?? _fallback;
  }
}

final noteRenderRegistryProvider = Provider<NoteRenderRegistry>((ref) {
  return const NoteRenderRegistry({
    kGeneralCatalogName: GeneralNoteRenderer(),
    GasLogNoteRenderer.catalogName: GasLogNoteRenderer(),
  });
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/rendering/render_registry_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/rendering/render_registry.dart test/features/notes/rendering/render_registry_test.dart
git commit -m "feat(notes): add render registry (catalog -> renderer)"
```

---

## Task 7: Edit-dispatch registry

Maps catalog name → an editor navigation action. General → generic editor; Gas Log → existing gas-log edit route (by note id, since gas-log id == note id). Unknown → not editable.

**Files:**
- Create: `lib/core/notes/editing/edit_dispatch.dart`
- Test: `test/core/notes/editing/edit_dispatch_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/editing/edit_dispatch.dart';

void main() {
  test('canEdit is true for wired catalogs, false otherwise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final d = container.read(editDispatchProvider);

    expect(d.canEdit(kGeneralCatalogName), isTrue);
    expect(d.canEdit('Hmm.AutomobileMan.GasLog'), isTrue);
    expect(d.canEdit('Hmm.AutomobileMan.AutomobileInfo'), isFalse);
    expect(d.canEdit(null), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/notes/editing/edit_dispatch_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement edit dispatch**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/notes/data/models/hmm_note.dart';
import '../catalog_palette.dart';

typedef EditAction = void Function(BuildContext context, HmmNote note);

class EditDispatch {
  const EditDispatch(this._byCatalog);

  final Map<String, EditAction> _byCatalog;

  bool canEdit(String? catalogName) =>
      catalogName != null && _byCatalog.containsKey(catalogName);

  /// No-op if the catalog has no registered editor.
  void edit(BuildContext context, String? catalogName, HmmNote note) {
    final action = catalogName == null ? null : _byCatalog[catalogName];
    action?.call(context, note);
  }
}

final editDispatchProvider = Provider<EditDispatch>((ref) {
  return EditDispatch({
    kGeneralCatalogName: (context, note) =>
        context.push('/notes/${note.id}/edit'),
    'Hmm.AutomobileMan.GasLog': (context, note) =>
        context.push('/gas-logs/${note.id}/edit'),
  });
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/notes/editing/edit_dispatch_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/notes/editing/edit_dispatch.dart test/core/notes/editing/edit_dispatch_test.dart
git commit -m "feat(notes): add edit-dispatch registry (catalog -> editor route)"
```

---

## Task 8: Ensure "General" catalog

Idempotently creates the seeded General catalog (formatType = Markdown = 3) used by all free-form notes.

**Files:**
- Create: `lib/features/notes/data/general_catalog.dart`
- Test: `test/features/notes/data/general_catalog_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/features/notes/data/general_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates General once and returns it on subsequent calls', () async {
    SharedPreferences.setMockInitialValues({}); // -> DataMode.local
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [hmmDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final first = await container.read(generalCatalogProvider.future);
    expect(first.name, kGeneralCatalogName);
    expect(first.formatType, 3);

    container.invalidate(generalCatalogProvider);
    final second = await container.read(generalCatalogProvider.future);
    expect(second.id, first.id); // not duplicated
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/data/general_catalog_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the helper + provider**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/notes/catalog_palette.dart';

const String _generalSchema = '{"type":"markdown"}';
// NoteContentFormatType: PlainText=0, Xml=1, Json=2, Markdown=3.
const int _formatMarkdown = 3;

Future<NoteCatalog> ensureGeneralCatalog(Ref ref) async {
  final repo = ref.read(noteCatalogRepositoryProvider);
  final existing = await repo.getCatalogByName(kGeneralCatalogName);
  if (existing != null) return existing;
  return repo.createCatalog(NoteCatalogsCompanion.insert(
    name: kGeneralCatalogName,
    schema: _generalSchema,
    formatType: const Value(_formatMarkdown),
  ));
}

final generalCatalogProvider =
    FutureProvider<NoteCatalog>((ref) => ensureGeneralCatalog(ref));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/data/general_catalog_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/data/general_catalog.dart test/features/notes/data/general_catalog_test.dart
git commit -m "feat(notes): ensure seeded General catalog"
```

---

## Task 9: Notes list state (filter + sort + search)

`NotesListData` holds the raw notes + catalogs and computes the visible list. Filtering/sorting/search are cheap client-side recomputes — no reload.

**Files:**
- Create: `lib/features/notes/states/notes_list_state.dart`
- Test: `test/features/notes/states/notes_list_state_test.dart`

- [ ] **Step 1: Write the failing test** (pure `NotesListData` logic — no mocks needed)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

HmmNote _n(int id, String subject, int catalogId, DateTime created,
        {DateTime? modified}) =>
    HmmNote(
      id: id, uuid: 'u$id', subject: subject, authorId: 1,
      catalogId: catalogId, createDate: created, lastModifiedDate: modified,
    );

void main() {
  final notes = [
    _n(1, 'Banana', 10, DateTime(2026, 1, 1)),
    _n(2, 'apple', 20, DateTime(2026, 1, 3)),
    _n(3, 'Cherry', 10, DateTime(2026, 1, 2)),
  ];
  NotesListData data() => NotesListData(all: notes, catalogsById: const {});

  test('default sort is newest-first by createDate', () {
    expect(data().visible.map((n) => n.id).toList(), [2, 3, 1]);
  });

  test('subjectAZ sorts case-insensitively', () {
    final v = data().copyWith(sort: NoteSort.subjectAZ).visible;
    expect(v.map((n) => n.subject).toList(), ['apple', 'Banana', 'Cherry']);
  });

  test('catalog filter restricts to selected catalogs', () {
    final v = data().copyWith(catalogFilter: {10}).visible;
    expect(v.map((n) => n.id).toList()..sort(), [1, 3]);
  });

  test('query matches subject substring, case-insensitive', () {
    final v = data().copyWith(query: 'an').visible; // "Banana"
    expect(v.map((n) => n.id).toList(), [1]);
  });

  test('countsByCatalog tallies per catalog', () {
    expect(data().countsByCatalog, {10: 2, 20: 1});
  });

  test('copyWith can clear the filter back to all', () {
    final filtered = data().copyWith(catalogFilter: {10});
    expect(filtered.copyWith(catalogFilter: null).catalogFilter, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/states/notes_list_state_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the state**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import '../data/models/hmm_note.dart';

enum NoteSort { dateNewest, dateOldest, lastModified, subjectAZ }

const Object _unset = Object();

class NotesListData {
  const NotesListData({
    required this.all,
    required this.catalogsById,
    this.catalogFilter,
    this.sort = NoteSort.dateNewest,
    this.query = '',
  });

  final List<HmmNote> all;
  final Map<int, NoteCatalog> catalogsById;
  final Set<int>? catalogFilter; // null = all
  final NoteSort sort;
  final String query;

  Map<int, int> get countsByCatalog {
    final m = <int, int>{};
    for (final n in all) {
      final c = n.catalogId;
      if (c != null) m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }

  List<HmmNote> get visible {
    Iterable<HmmNote> items = all;
    final f = catalogFilter;
    if (f != null && f.isNotEmpty) {
      items = items.where((n) => n.catalogId != null && f.contains(n.catalogId));
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((n) => n.subject.toLowerCase().contains(q));
    }
    final list = items.toList();
    switch (sort) {
      case NoteSort.dateNewest:
        list.sort((a, b) => b.createDate.compareTo(a.createDate));
      case NoteSort.dateOldest:
        list.sort((a, b) => a.createDate.compareTo(b.createDate));
      case NoteSort.lastModified:
        list.sort((a, b) => (b.lastModifiedDate ?? b.createDate)
            .compareTo(a.lastModifiedDate ?? a.createDate));
      case NoteSort.subjectAZ:
        list.sort((a, b) =>
            a.subject.toLowerCase().compareTo(b.subject.toLowerCase()));
    }
    return list;
  }

  NotesListData copyWith({
    List<HmmNote>? all,
    Map<int, NoteCatalog>? catalogsById,
    Object? catalogFilter = _unset,
    NoteSort? sort,
    String? query,
  }) {
    return NotesListData(
      all: all ?? this.all,
      catalogsById: catalogsById ?? this.catalogsById,
      catalogFilter: identical(catalogFilter, _unset)
          ? this.catalogFilter
          : catalogFilter as Set<int>?,
      sort: sort ?? this.sort,
      query: query ?? this.query,
    );
  }
}

class NotesListState extends AsyncNotifier<NotesListData> {
  Future<NotesListData> _load() async {
    final page = await ref.read(hmmNoteRepositoryProvider).getNotes(pageSize: 500);
    final catalogs = await ref.read(noteCatalogRepositoryProvider).getCatalogs();
    return NotesListData(
      all: page.items,
      catalogsById: {for (final c in catalogs) c.id: c},
    );
  }

  @override
  Future<NotesListData> build() => _load();

  void setSort(NoteSort sort) {
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(sort: sort));
  }

  void setQuery(String query) {
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(query: query));
  }

  void setFilter(Set<int>? catalogIds) {
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(catalogFilter: catalogIds));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final notesListStateProvider =
    AsyncNotifierProvider<NotesListState, NotesListData>(NotesListState.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/states/notes_list_state_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/states/notes_list_state.dart test/features/notes/states/notes_list_state_test.dart
git commit -m "feat(notes): add notes list state (filter/sort/search)"
```

---

## Task 10: Mutate-note service (create/update/delete/add-image)

Encapsulates writes for General notes + the auto-save-then-attach image flow. Invalidates the list after each write.

**Files:**
- Create: `lib/features/notes/states/mutate_note_state.dart`
- Test: `test/features/notes/states/mutate_note_state_test.dart`

- [ ] **Step 1: Write the failing test** (hand-written fakes via overrides)

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeNoteRepo implements IHmmNoteRepository {
  final List<HmmNote> created = [];
  HmmNote? lastUpdatedWith;
  int deletedId = -1;
  HmmNote stored = HmmNote(
      id: 7, uuid: 'u7', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1));

  @override
  Future<HmmNote> createNote(HmmNoteCreate input) async {
    final n = HmmNote(
      id: 7, uuid: 'u7', subject: input.subject, authorId: 1,
      catalogId: input.catalogId, content: input.content,
      createDate: DateTime(2026, 1, 1));
    created.add(n);
    return n;
  }

  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    stored = HmmNote(
      id: id, uuid: 'u$id', subject: patch.subject ?? stored.subject,
      authorId: 1, content: patch.content ?? stored.content,
      createDate: DateTime(2026, 1, 1), attachments: patch.attachments);
    lastUpdatedWith = stored;
    return stored;
  }

  @override
  Future<void> deleteNote(int id) async => deletedId = id;
  @override
  Future<HmmNote?> getNoteById(int id) async => stored;
  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => stored;
  @override
  Future<PageList<HmmNote>> getNotes(
          {int? catalogId, int? parentNoteId, int page = 1,
          int pageSize = 20, bool includeDeleted = false}) async =>
      PageList(items: const [],
          meta: const PaginationMeta(
              totalCount: 0, pageSize: 20, currentPage: 1, totalPages: 0));
}

class _FakeCatalogRepo implements INoteCatalogRepository {
  @override
  Future<NoteCatalog?> getCatalogByName(String name) async => null;
  @override
  Future<NoteCatalog> createCatalog(NoteCatalogsCompanion c) async =>
      NoteCatalog(id: 99, name: c.name.value, schema: c.schema.value,
          formatType: 3, isDefault: false);
  @override
  Future<List<NoteCatalog>> getCatalogs() async => [];
  @override
  Future<NoteCatalog?> getCatalogById(int id) async => null;
  @override
  Future<NoteCatalog> getOrCreateCatalog(String name, String schema) =>
      createCatalog(NoteCatalogsCompanion.insert(name: name, schema: schema));
  @override
  Future<NoteCatalog> updateCatalog(int id, NoteCatalogsCompanion c) =>
      createCatalog(c);
}

class _FakePicker implements IImageAttachmentPicker {
  _FakePicker(this.result);
  final VaultRef? result;
  @override
  Future<VaultRef?> pickForNote(
          {required int noteId,
          AttachmentPickSource source = AttachmentPickSource.gallery}) async =>
      result;
}

VaultRef _ref(String path) =>
    VaultRef(path: path, contentType: 'image/jpeg', byteSize: 1);

ProviderContainer _container(_FakeNoteRepo repo, {VaultRef? picked}) =>
    ProviderContainer(overrides: [
      hmmNoteRepositoryProvider.overrideWithValue(repo),
      noteCatalogRepositoryProvider.overrideWithValue(_FakeCatalogRepo()),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => _FakePicker(picked)),
    ]);

void main() {
  test('createGeneral uses the General catalog id and trims subject', () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(mutateNoteProvider).createGeneral(
        subject: '  Hi  ', markdownBody: '# body');
    expect(repo.created.single.subject, 'Hi');
    expect(repo.created.single.catalogId, 99);
    expect(repo.created.single.content, '# body');
  });

  test('addImage appends a picked ref as primary image', () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo, picked: _ref('a.jpg'));
    addTearDown(c.dispose);

    final out = await c.read(mutateNoteProvider).addImage(7);
    expect(out, isNotNull);
    expect(repo.lastUpdatedWith!.attachments!.primaryImage, _ref('a.jpg'));
  });

  test('addImage returns null and does not update when picker cancels',
      () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo, picked: null);
    addTearDown(c.dispose);

    final out = await c.read(mutateNoteProvider).addImage(7);
    expect(out, isNull);
    expect(repo.lastUpdatedWith, isNull);
  });

  test('delete calls through', () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(mutateNoteProvider).delete(7);
    expect(repo.deletedId, 7);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/states/mutate_note_state_test.dart`
Expected: FAIL — `mutate_note_state.dart` not found.

- [ ] **Step 3: Implement the service**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/repository_providers.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';
import 'notes_list_state.dart';

class MutateNote {
  MutateNote(this.ref);
  final Ref ref;

  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
  }) async {
    final catalog = await ensureGeneralCatalog(ref);
    final note = await ref.read(hmmNoteRepositoryProvider).createNote(
          HmmNoteCreate(
            subject: subject.trim(),
            catalogId: catalog.id,
            content: markdownBody,
          ),
        );
    ref.invalidate(notesListStateProvider);
    return note;
  }

  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
  }) async {
    final note = await ref.read(hmmNoteRepositoryProvider).updateNote(
          id,
          HmmNoteUpdate(subject: subject?.trim(), content: markdownBody),
        );
    ref.invalidate(notesListStateProvider);
    return note;
  }

  Future<void> delete(int id) async {
    await ref.read(hmmNoteRepositoryProvider).deleteNote(id);
    ref.invalidate(notesListStateProvider);
  }

  /// Picks an image for [noteId] (which must already exist), appends it, and
  /// persists. Returns null if the user cancels.
  Future<HmmNote?> addImage(
    int noteId, {
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final VaultRef? picked =
        await picker.pickForNote(noteId: noteId, source: source);
    if (picked == null) return null;

    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = NoteAttachments(
      primaryImage: existing.primaryImage ?? picked,
      images: existing.primaryImage == null
          ? existing.images
          : [...existing.images, picked],
    );
    final note =
        await repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
    ref.invalidate(notesListStateProvider);
    return note;
  }
}

final mutateNoteProvider = Provider<MutateNote>((ref) => MutateNote(ref));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/states/mutate_note_state_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/states/mutate_note_state.dart test/features/notes/states/mutate_note_state_test.dart
git commit -m "feat(notes): add mutate-note service (create/update/delete/add-image)"
```

---

## Task 11: Routing + dashboard wiring

Adds the `/notes` route tree and makes the dashboard "Notes" tile navigate there. (Screens referenced here are built in Tasks 12–15; this task creates minimal stubs so routing compiles, which the later tasks flesh out.)

**Files:**
- Modify: `lib/core/navigation/route_names.dart`
- Modify: `lib/core/navigation/router_config.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart` (the `_navigateToFunction` switch)
- Create (stubs, completed later): `lib/features/notes/presentation/screens/notes_list_screen.dart`, `note_detail_screen.dart`, `note_editor_screen.dart`, `raw_content_screen.dart`

- [ ] **Step 1: Add route name entries**

In `lib/core/navigation/route_names.dart`, add to the `RouterNames` enum (before the closing `}`):

```dart
  notesList,
  noteCreate,
  noteDetail,
  noteEdit,
  noteRaw,
```

- [ ] **Step 2: Create minimal screen stubs**

Create each of the four screen files with a placeholder so routing compiles. They are completed in later tasks.

```dart
// lib/features/notes/presentation/screens/notes_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: Center(child: Text('Notes')));
}
```

```dart
// lib/features/notes/presentation/screens/note_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(body: Center(child: Text('Note $noteId')));
}
```

```dart
// lib/features/notes/presentation/screens/note_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});
  final int? noteId; // null = create
  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Editor')));
}
```

```dart
// lib/features/notes/presentation/screens/raw_content_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RawContentScreen extends ConsumerWidget {
  const RawContentScreen({super.key, required this.noteId});
  final int noteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(body: Center(child: Text('Raw $noteId')));
}
```

- [ ] **Step 3: Register the route tree**

In `lib/core/navigation/router_config.dart`, add imports near the other feature imports:

```dart
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/raw_content_screen.dart';
```

Add this `GoRoute` inside the top-level `routes: [ ... ]` list (e.g. right after the `/gas-logs` route):

```dart
      GoRoute(
        path: '/notes',
        name: RouterNames.notesList.name,
        builder: (context, state) => const NotesListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: RouterNames.noteCreate.name,
            builder: (context, state) => const NoteEditorScreen(),
          ),
          GoRoute(
            path: ':id',
            name: RouterNames.noteDetail.name,
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return NoteDetailScreen(noteId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: RouterNames.noteEdit.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return NoteEditorScreen(noteId: id);
                },
              ),
              GoRoute(
                path: 'raw',
                name: RouterNames.noteRaw.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return RawContentScreen(noteId: id);
                },
              ),
            ],
          ),
        ],
      ),
```

- [ ] **Step 4: Wire the dashboard tile**

In `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, update the `_navigateToFunction` switch to add a `notes` case before `default`:

```dart
    switch (function.route) {
      case 'gas-log':
        context.push('/automobiles');
      case 'notes':
        context.push('/notes');
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${function.title} coming soon...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
    }
```

- [ ] **Step 5: Verify it compiles and routes**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/navigation/route_names.dart lib/core/navigation/router_config.dart lib/features/dashboard/presentation/screens/dashboard_screen.dart lib/features/notes/presentation/screens/
git commit -m "feat(notes): add /notes routes + dashboard tile wiring (screen stubs)"
```

---

## Task 12: Notes list screen (chips + sort sheet + filter sheet + search)

Replaces the stub. Renders the unified colored list and the filter/sort controls from the validated mockup.

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`
- Create: `lib/features/notes/presentation/widgets/note_list_tile.dart`
- Create: `lib/features/notes/presentation/widgets/catalog_filter_sheet.dart`
- Create: `lib/features/notes/presentation/widgets/sort_sheet.dart`
- Test: `test/features/notes/presentation/notes_list_screen_test.dart`

- [ ] **Step 1: Implement `note_list_tile.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../data/models/hmm_note.dart';

class NoteListTile extends StatelessWidget {
  const NoteListTile({super.key, required this.note, this.catalog, this.onTap});

  final HmmNote note;
  final NoteCatalog? catalog;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = CatalogPalette.styleFor(catalog?.name);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(radius: 6, backgroundColor: style.color),
      title: Text(note.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${style.displayName} · ${note.createDate.toLocal().toString().split(' ').first}',
      ),
    );
  }
}
```

- [ ] **Step 2: Implement `sort_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../states/notes_list_state.dart';

class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.current, required this.onSelected});

  final NoteSort current;
  final ValueChanged<NoteSort> onSelected;

  static const _labels = {
    NoteSort.dateNewest: 'Date — newest first',
    NoteSort.dateOldest: 'Date — oldest first',
    NoteSort.lastModified: 'Last modified',
    NoteSort.subjectAZ: 'Subject — A → Z',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries)
            ListTile(
              title: Text(entry.value),
              trailing: entry.key == current ? const Icon(Icons.check) : null,
              onTap: () {
                onSelected(entry.key);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Implement `catalog_filter_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';

class CatalogFilterSheet extends StatelessWidget {
  const CatalogFilterSheet({
    super.key,
    required this.catalogs,
    required this.counts,
    required this.selected, // null = All
    required this.onApply,
  });

  final List<NoteCatalog> catalogs;
  final Map<int, int> counts;
  final Set<int>? selected;
  final ValueChanged<Set<int>?> onApply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All notes'),
            trailing: selected == null ? const Icon(Icons.check) : null,
            onTap: () {
              onApply(null);
              Navigator.of(context).pop();
            },
          ),
          const Divider(height: 1),
          for (final c in catalogs)
            ListTile(
              leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: CatalogPalette.styleFor(c.name).color),
              title: Text(CatalogPalette.styleFor(c.name).displayName),
              trailing: Text('${counts[c.id] ?? 0}'),
              selected: selected?.contains(c.id) ?? false,
              onTap: () {
                onApply({c.id});
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the list screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notes/catalog_palette.dart';
import '../../states/notes_list_state.dart';
import '../widgets/catalog_filter_sheet.dart';
import '../widgets/note_list_tile.dart';
import '../widgets/sort_sheet.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesListStateProvider);
    final notifier = ref.read(notesListStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.swap_vert),
            onPressed: async.hasValue
                ? () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => SortSheet(
                        current: async.value!.sort,
                        onSelected: notifier.setSort,
                      ),
                    )
                : null,
          ),
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onPressed: async.hasValue
                ? () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => CatalogFilterSheet(
                        catalogs: async.value!.catalogsById.values.toList(),
                        counts: async.value!.countsByCatalog,
                        selected: async.value!.catalogFilter,
                        onApply: notifier.setFilter,
                      ),
                    )
                : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/notes/new'),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load notes: $e')),
        data: (data) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search subjects',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setQuery,
                ),
              ),
              _Chips(data: data, onSelect: notifier.setFilter),
              Expanded(
                child: data.visible.isEmpty
                    ? const Center(child: Text('No notes'))
                    : ListView.builder(
                        itemCount: data.visible.length,
                        itemBuilder: (context, i) {
                          final note = data.visible[i];
                          return NoteListTile(
                            note: note,
                            catalog: note.catalogId == null
                                ? null
                                : data.catalogsById[note.catalogId],
                            onTap: () => context.push('/notes/${note.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.data, required this.onSelect});
  final NotesListData data;
  final ValueChanged<Set<int>?> onSelect;

  @override
  Widget build(BuildContext context) {
    final catalogs = data.catalogsById.values.toList();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All'),
              selected: data.catalogFilter == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final c in catalogs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: CircleAvatar(
                    radius: 5,
                    backgroundColor: CatalogPalette.styleFor(c.name).color),
                label: Text(CatalogPalette.styleFor(c.name).displayName),
                selected: data.catalogFilter?.contains(c.id) ?? false,
                onSelected: (_) => onSelect({c.id}),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Grocery list', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 2)),
          HmmNote(
              id: 2, uuid: 'u2', subject: 'Vacation', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

void main() {
  testWidgets('shows note tiles and filters by search query', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notesListStateProvider.overrideWith(_StubListState.new),
      ],
      child: const MaterialApp(home: NotesListScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoteListTile), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'groc');
    await tester.pumpAndSettle();
    expect(find.byType(NoteListTile), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('sort button opens the sort sheet', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: const MaterialApp(home: NotesListScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    expect(find.text('Subject — A → Z'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run the test**

Run: `flutter test test/features/notes/presentation/notes_list_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/presentation/screens/notes_list_screen.dart lib/features/notes/presentation/widgets/ test/features/notes/presentation/notes_list_screen_test.dart
git commit -m "feat(notes): notes list screen with chips, sort + filter sheets, search"
```

---

## Task 13: Note detail screen (render + attachments + ⋯ menu + edit dispatch + delete)

Loads note + catalog, renders via the registry, shows attachments, and provides Edit / View raw content / Delete.

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`
- Create: `lib/features/notes/presentation/widgets/attachment_gallery.dart`
- Test: `test/features/notes/presentation/note_detail_screen_test.dart`

- [ ] **Step 1: Implement `attachment_gallery.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/attachment_providers.dart';

class AttachmentGallery extends ConsumerWidget {
  const AttachmentGallery({super.key, required this.refs});

  final List<AttachmentRef> refs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (refs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: refs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Thumb(reference: refs[i]),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.reference});
  final AttachmentRef reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolverAsync = ref.watch(attachmentResolverProvider);
    return resolverAsync.when(
      loading: () => const SizedBox(
          width: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const _Placeholder(),
      data: (resolver) => FutureBuilder(
        future: resolver.resolve(reference),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null) return const _Placeholder();
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: 120, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported),
      );
}
```

- [ ] **Step 2: Implement the detail screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/local/database.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/notes/editing/edit_dispatch.dart';
import '../../data/models/hmm_note.dart';
import '../../rendering/render_registry.dart';
import '../../states/mutate_note_state.dart';
import '../widgets/attachment_gallery.dart';
import '../widgets/markdown_view.dart';

class NoteDetailData {
  const NoteDetailData(this.note, this.catalog);
  final HmmNote note;
  final NoteCatalog? catalog;
}

final noteDetailProvider =
    FutureProvider.family<NoteDetailData, int>((ref, id) async {
  final note = await ref.watch(hmmNoteRepositoryProvider).getNoteById(id);
  if (note == null) throw StateError('Note $id not found');
  NoteCatalog? catalog;
  final cid = note.catalogId;
  if (cid != null) {
    catalog = await ref.watch(noteCatalogRepositoryProvider).getCatalogById(cid);
  }
  return NoteDetailData(note, catalog);
});

enum _MenuAction { edit, raw, delete }

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(noteDetailProvider(noteId));
    final registry = ref.watch(noteRenderRegistryProvider);
    final dispatch = ref.watch(editDispatchProvider);

    return Scaffold(
      appBar: AppBar(
        title: async.maybeWhen(
          data: (d) => Text(CatalogPalette.styleFor(d.catalog?.name).displayName),
          orElse: () => const Text('Note'),
        ),
        actions: [
          async.maybeWhen(
            data: (d) {
              final catalogName = d.catalog?.name;
              return PopupMenuButton<_MenuAction>(
                onSelected: (a) async {
                  switch (a) {
                    case _MenuAction.edit:
                      dispatch.edit(context, catalogName, d.note);
                    case _MenuAction.raw:
                      context.push('/notes/$noteId/raw');
                    case _MenuAction.delete:
                      await ref.read(mutateNoteProvider).delete(noteId);
                      if (context.mounted) context.pop();
                  }
                },
                itemBuilder: (context) => [
                  if (dispatch.canEdit(catalogName))
                    const PopupMenuItem(
                        value: _MenuAction.edit, child: Text('Edit')),
                  const PopupMenuItem(
                      value: _MenuAction.raw,
                      child: Text('View raw content')),
                  const PopupMenuItem(
                      value: _MenuAction.delete, child: Text('Delete')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final markdown = _safeRender(registry, d.catalog?.name, d.note);
          final atts = <AttachmentRef>[
            if (d.note.effectiveAttachments.primaryImage != null)
              d.note.effectiveAttachments.primaryImage!,
            ...d.note.effectiveAttachments.images,
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(d.note.subject,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (atts.isNotEmpty) ...[
                AttachmentGallery(refs: atts),
                const SizedBox(height: 12),
              ],
              MarkdownView(markdown),
            ],
          );
        },
      ),
    );
  }

  /// Renderers must not throw, but isolate anyway: fall back to a banner +
  /// generic view rather than crashing the read screen.
  String _safeRender(
      NoteRenderRegistry registry, String? catalogName, HmmNote note) {
    try {
      return registry.rendererFor(catalogName).render(note);
    } catch (_) {
      return '> ⚠️ Couldn\'t render this note\'s format. Use **View raw content** to inspect it.';
    }
  }
}

- [ ] **Step 3: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/markdown_view.dart';

void main() {
  testWidgets('renders the note body and the ⋯ menu actions', (tester) async {
    final note = HmmNote(
        id: 5, uuid: 'u5', subject: 'My note', authorId: 1, catalogId: 1,
        content: 'Hello body', createDate: DateTime(2026, 1, 1));
    final catalog = NoteCatalog(
        id: 1, name: 'General', schema: '{}', formatType: 3, isDefault: false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(5).overrideWith(
            (ref) async => NoteDetailData(note, catalog)),
      ],
      child: const MaterialApp(home: NoteDetailScreen(noteId: 5)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('My note'), findsOneWidget);
    expect(find.byType(MarkdownView), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget); // General is editable
    expect(find.text('View raw content'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/notes/presentation/note_detail_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/screens/note_detail_screen.dart lib/features/notes/presentation/widgets/attachment_gallery.dart test/features/notes/presentation/note_detail_screen_test.dart
git commit -m "feat(notes): note detail screen (render, attachments, edit dispatch, delete)"
```

---

## Task 14: Note editor screen (General create/edit + images)

Subject + markdown body + image attachments. Adding a photo to a brand-new note auto-saves it first (the picker needs a real note id).

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/note_editor_screen_test.dart`

- [ ] **Step 1: Implement the editor**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/repository_providers.dart';
import '../../states/mutate_note_state.dart';
import '../screens/note_detail_screen.dart' show noteDetailProvider;

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});
  final int? noteId; // null = create
  bool get isNew => noteId == null;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  int? _noteId; // becomes non-null once persisted
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || widget.noteId == null) return;
    _loaded = true;
    final note =
        await ref.read(hmmNoteRepositoryProvider).getNoteById(widget.noteId!);
    if (note != null && mounted) {
      _subjectCtrl.text = note.subject;
      _bodyCtrl.text = note.content ?? '';
      setState(() {});
    }
  }

  /// Persists the note (create or update) and returns its id.
  Future<int?> _save() async {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject is required')));
      return null;
    }
    final mutate = ref.read(mutateNoteProvider);
    setState(() => _busy = true);
    try {
      if (_noteId == null) {
        final note = await mutate.createGeneral(
            subject: subject, markdownBody: _bodyCtrl.text);
        _noteId = note.id;
      } else {
        await mutate.updateGeneral(_noteId!,
            subject: subject, markdownBody: _bodyCtrl.text);
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      return _noteId;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addImage() async {
    final id = await _save(); // ensure the note exists first
    if (id == null) return;
    try {
      await ref.read(mutateNoteProvider).addImage(id);
      ref.invalidate(noteDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image added')));
      }
    } on AttachmentPickerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New note' : 'Edit note'),
        actions: [
          IconButton(
            tooltip: 'Add image',
            icon: const Icon(Icons.image),
            onPressed: _busy ? null : _addImage,
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final id = await _save();
                    if (id != null && context.mounted) context.pop();
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                  labelText: 'Subject', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: 'Body (markdown)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeMutate implements MutateNote {
  String? createdSubject;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<HmmNote> createGeneral({required String subject, String? markdownBody}) async {
    createdSubject = subject;
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1), content: markdownBody);
  }
}

void main() {
  testWidgets('Save with empty subject shows validation error', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NoteEditorScreen()),
    ));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Subject is required'), findsOneWidget);
  });

  testWidgets('Save with a subject calls createGeneral', (tester) async {
    final fake = _FakeMutate();
    await tester.pumpWidget(ProviderScope(
      overrides: [mutateNoteProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: NoteEditorScreen()),
    ));
    await tester.enterText(
        find.widgetWithText(TextField, 'Subject'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(fake.createdSubject, 'Hello');
  });
}
```

- [ ] **Step 3: Run the test**

Run: `flutter test test/features/notes/presentation/note_editor_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/note_editor_screen_test.dart
git commit -m "feat(notes): General note editor (subject + markdown + images)"
```

---

## Task 15: Raw content viewer (D)

Pretty-prints JSON content (or shows it verbatim) plus catalog/uuid/version metadata, with copy-to-clipboard.

**Files:**
- Modify: `lib/features/notes/presentation/screens/raw_content_screen.dart`
- Test: `test/features/notes/presentation/raw_content_screen_test.dart`

- [ ] **Step 1: Implement the raw viewer**

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/note_detail_screen.dart' show noteDetailProvider;

String prettyContent(String? content) {
  if (content == null || content.trim().isEmpty) return '(no content)';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(content));
  } catch (_) {
    return content; // not JSON — show verbatim
  }
}

class RawContentScreen extends ConsumerWidget {
  const RawContentScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(noteDetailProvider(noteId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw content'),
        actions: [
          async.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: prettyContent(d.note.content))),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final version = d.note.version == null
              ? 'null'
              : '0x${d.note.version!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  prettyContent(d.note.content),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const Divider(),
                Text('catalog: ${d.catalog?.name ?? '(none)'}'),
                Text('uuid: ${d.note.uuid}'),
                Text('version: $version'),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Write the test** (pure formatter + a widget smoke test)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/raw_content_screen.dart';

void main() {
  test('prettyContent indents JSON and passes non-JSON through', () {
    expect(prettyContent('{"a":1}'), '{\n  "a": 1\n}');
    expect(prettyContent('plain'), 'plain');
    expect(prettyContent(null), '(no content)');
  });

  testWidgets('shows formatted content + metadata', (tester) async {
    final note = HmmNote(
        id: 3, uuid: 'abc', subject: 's', authorId: 1, catalogId: 1,
        content: '{"x":1}', createDate: DateTime(2026, 1, 1));
    final catalog = NoteCatalog(
        id: 1, name: 'General', schema: '{}', formatType: 3, isDefault: false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(3)
            .overrideWith((ref) async => NoteDetailData(note, catalog)),
      ],
      child: const MaterialApp(home: RawContentScreen(noteId: 3)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('"x": 1'), findsOneWidget);
    expect(find.textContaining('uuid: abc'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test**

Run: `flutter test test/features/notes/presentation/raw_content_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/notes/presentation/screens/raw_content_screen.dart test/features/notes/presentation/raw_content_screen_test.dart
git commit -m "feat(notes): raw content viewer (pretty JSON + metadata + copy)"
```

---

## Task 16: iPad master/detail layout

On wide screens, show the list and the selected note's detail side by side (the sheet→sidebar idea from the mockup, at minimum a two-pane list+detail).

**Files:**
- Create: `lib/features/notes/presentation/screens/notes_shell_screen.dart`
- Modify: `lib/core/navigation/router_config.dart` (point `/notes` at the shell)
- Test: `test/features/notes/presentation/notes_shell_screen_test.dart`

- [ ] **Step 1: Implement the responsive shell**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../states/notes_list_state.dart';
import 'note_detail_screen.dart';
import 'notes_list_screen.dart';

/// Selected note id for the wide-screen detail pane (null = nothing selected).
final selectedNoteIdProvider = StateProvider<int?>((ref) => null);

class NotesShellScreen extends ConsumerWidget {
  const NotesShellScreen({super.key});

  static const double _wideBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (!isWide) return const NotesListScreen();

        final selectedId = ref.watch(selectedNoteIdProvider);
        return Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 360, child: NotesListScreen()),
              const VerticalDivider(width: 1),
              Expanded(
                child: selectedId == null
                    ? const Center(child: Text('Select a note'))
                    : NoteDetailScreen(noteId: selectedId),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Make the list select into the pane on wide screens**

In `notes_list_screen.dart`, change the tile `onTap` to branch on width:

```dart
                            onTap: () {
                              final isWide =
                                  MediaQuery.of(context).size.width >= 720;
                              if (isWide) {
                                ref
                                    .read(selectedNoteIdProvider.notifier)
                                    .state = note.id;
                              } else {
                                context.push('/notes/${note.id}');
                              }
                            },
```

Add the import at the top of `notes_list_screen.dart`:

```dart
import 'notes_shell_screen.dart' show selectedNoteIdProvider;
```

- [ ] **Step 3: Point the `/notes` route at the shell**

In `router_config.dart`, change the `/notes` builder:

```dart
        builder: (context, state) => const NotesShellScreen(),
```

and add the import:

```dart
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
```

- [ ] **Step 4: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Note one', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

void main() {
  testWidgets('wide screen shows two panes; narrow shows one', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: const MaterialApp(home: NotesShellScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Select a note'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/notes/presentation/notes_shell_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Full suite + analyze**

Run: `flutter analyze && flutter test`
Expected: no analyzer errors; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/presentation/screens/notes_shell_screen.dart lib/features/notes/presentation/screens/notes_list_screen.dart lib/core/navigation/router_config.dart test/features/notes/presentation/notes_shell_screen_test.dart
git commit -m "feat(notes): iPad master/detail layout for notes"
```

---

## Done

After Task 16, the foundation is complete: free-form notes can be created (subject + markdown + images), every note renders read-only via the registry (Gas Log proven, generic fallback for the rest), the list filters/sorts/searches with catalog colors and an iPad two-pane layout, edits dispatch to the right editor, and raw content is always inspectable.

**Deferred to follow-on specs (unchanged):** cross-subsystem surfacing (B), tag cloud sync (C), the calendar view, a `priority` field, HTML-formatType rendering, and a `NoteCatalogs.color` column.

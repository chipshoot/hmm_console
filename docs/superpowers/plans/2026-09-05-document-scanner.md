# Document Scanner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture licence photos through the OS document scanner, so each side comes out cropped to the card, deskewed and de-shadowed.

**Architecture:** A `DocumentScanner` Dart interface behind a Riverpod provider, implemented by a `MethodChannel` client talking to a thin Swift plugin around `VNDocumentCameraViewController`. All decision logic lives in Dart; the Swift only presents, collects and encodes.

**Tech Stack:** Flutter, Riverpod, Swift + VisionKit, `MethodChannel`. **No new pub dependency.**

**Spec:** `docs/superpowers/specs/2026-09-04-document-scanner-design.md`

## Global Constraints

- **No third-party plugin.** Identity documents must not pass through unmaintained code.
- **Bytes across the channel, never file paths.** A path means a plaintext JPEG of an ID in the app's tmp directory, outside the vault.
- **The Swift stays dumb** — present, collect, encode. It cannot be unit-tested and does not run on the simulator, so any rule that could be wrong belongs in Dart.
- **Licence only.** Registration scans, health card, passport and receipts come later.
- **`ensureVaultUnlocked()` runs BEFORE the scanner opens** (`lib/core/data/vault/ensure_vault_unlocked.dart`). Scanning and then losing the result is the bug fixed in `457cbf7`.
- **Existing types.** Return `PickedImageBytes` so `persistToVault(sensitive: true)` and downsizing work unchanged.
- Every user-facing string goes through ARB, `en` and `zh`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/data/attachments/scanner/document_scanner.dart` | Interface + provider + the unavailable default |
| `lib/core/data/attachments/scanner/native_document_scanner.dart` | MethodChannel client, error mapping |
| `lib/features/driver_licence/domain/licence_scan_mapping.dart` | Pure page→side rules |
| `ios/Runner/DocumentScannerPlugin.swift` | VisionKit presentation |
| `ios/Runner/AppDelegate.swift` | Registration |
| `lib/features/driver_licence/presentation/screens/driver_licence_screen.dart` | Scan action |

---

### Task 1: The interface and its unavailable default

**Files:**
- Create: `lib/core/data/attachments/scanner/document_scanner.dart`
- Test: `test/core/data/attachments/scanner/document_scanner_test.dart`

**Interfaces:**
- Produces: `DocumentScanner` (`Future<bool> isAvailable()`, `Future<List<PickedImageBytes>> scan()`); `documentScannerProvider`; `UnavailableDocumentScanner`.

- [x] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/scanner/document_scanner.dart';

void main() {
  test('the default scanner reports itself unavailable and scans nothing',
      () async {
    // Every platform except iOS-with-VisionKit gets this one, so it must be
    // safe rather than throwing: the UI hides the scan action when
    // isAvailable() is false and never calls scan().
    const scanner = UnavailableDocumentScanner();

    expect(await scanner.isAvailable(), isFalse);
    expect(await scanner.scan(), isEmpty);
  });
}
```

- [x] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/data/attachments/scanner/document_scanner_test.dart`
Expected: FAIL — `document_scanner.dart` does not exist.

- [x] **Step 3: Write the interface**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../picker/image_byte_source.dart';

/// The OS document scanner: edge detection, perspective correction and shadow
/// removal, done by the platform rather than by us.
///
/// Returns [PickedImageBytes] — the same type the camera picker returns — so
/// everything downstream (pending picks, `persistToVault(sensitive: true)`,
/// downsizing) works unchanged.
abstract interface class DocumentScanner {
  /// False on the simulator, on Android until its half lands, and on iOS
  /// versions without VisionKit. Callers must check this and hide the scan
  /// affordance rather than offering something that cannot work.
  Future<bool> isAvailable();

  /// One entry per page, in capture order. Empty when the user cancels.
  Future<List<PickedImageBytes>> scan();
}

/// The default everywhere the platform cannot scan. Deliberately silent: an
/// unavailable scanner is not an error, it is a reason to show the plain
/// camera instead.
class UnavailableDocumentScanner implements DocumentScanner {
  const UnavailableDocumentScanner();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<PickedImageBytes>> scan() async => const [];
}

final documentScannerProvider = Provider<DocumentScanner>(
  (ref) => const UnavailableDocumentScanner(),
);
```

- [x] **Step 4: Run it and watch it pass**

Run: `flutter test test/core/data/attachments/scanner/document_scanner_test.dart`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/core/data/attachments/scanner test/core/data/attachments/scanner
git commit -m "feat(scanner): add the DocumentScanner seam"
```

---

### Task 2: The page-to-side rules

This is where every rule that could be wrong lives, precisely because the Swift cannot be tested.

**Files:**
- Create: `lib/features/driver_licence/domain/licence_scan_mapping.dart`
- Test: `test/features/driver_licence/licence_scan_mapping_test.dart`

**Interfaces:**
- Produces: `LicenceScanPages` with `front`, `back`, `ignoredPageCount`; `LicenceScanPages.fromScan(List<PickedImageBytes>)`.

- [x] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/features/driver_licence/domain/licence_scan_mapping.dart';

PickedImageBytes page(int n) => PickedImageBytes(
      bytes: Uint8List.fromList([n]),
      originalName: 'page$n.jpg',
      contentType: 'image/jpeg',
    );

void main() {
  test('no pages means the user cancelled and nothing changes', () {
    final r = LicenceScanPages.fromScan(const []);
    expect(r.front, isNull);
    expect(r.back, isNull);
    expect(r.ignoredPageCount, 0);
  });

  test('one page is the front', () {
    final r = LicenceScanPages.fromScan([page(1)]);
    expect(r.front, page(1));
    expect(r.back, isNull);
    expect(r.ignoredPageCount, 0);
  });

  test('two pages are front then back, in capture order', () {
    final r = LicenceScanPages.fromScan([page(1), page(2)]);
    expect(r.front, page(1));
    expect(r.back, page(2));
    expect(r.ignoredPageCount, 0);
  });

  test('extra pages are counted, not silently dropped', () {
    // The user shot four pages; they must be told two were ignored rather
    // than left wondering where they went.
    final r = LicenceScanPages.fromScan([page(1), page(2), page(3), page(4)]);
    expect(r.front, page(1));
    expect(r.back, page(2));
    expect(r.ignoredPageCount, 2);
  });
}
```

- [x] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/driver_licence/licence_scan_mapping_test.dart`
Expected: FAIL — `licence_scan_mapping.dart` does not exist.

RESOLVED: `PickedImageBytes` has `copyWith` but NO `==`, so value comparison
fails on identity. The tests use `same()` instead — a stronger claim than
matching a filename, since the mapping should hand back the very instances it
was given, and it needs no change to a shared type.

- [x] **Step 3: Write the mapping**

```dart
import '../../../core/data/attachments/picker/image_byte_source.dart';

/// Maps one scanning session onto a licence's two sides.
///
/// VisionKit returns however many pages the user shot. A licence has exactly
/// two sides, so the rules are fixed here, in Dart, where a test can reach
/// them — the Swift side deliberately knows nothing about licences.
class LicenceScanPages {
  const LicenceScanPages({this.front, this.back, this.ignoredPageCount = 0});

  final PickedImageBytes? front;
  final PickedImageBytes? back;

  /// Pages beyond the second. Surfaced so the screen can say they were
  /// ignored; dropping them silently would look like lost work.
  final int ignoredPageCount;

  factory LicenceScanPages.fromScan(List<PickedImageBytes> pages) =>
      LicenceScanPages(
        front: pages.isNotEmpty ? pages[0] : null,
        back: pages.length > 1 ? pages[1] : null,
        ignoredPageCount: pages.length > 2 ? pages.length - 2 : 0,
      );
}
```

- [x] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/driver_licence/licence_scan_mapping_test.dart`
Expected: PASS (4 tests)

- [x] **Step 5: Mutation-check**

Swap `pages[0]` and `pages[1]`. Expected: the two-page test fails. Restore.
Change `ignoredPageCount` to always `0`. Expected: the extra-pages test fails. Restore.

- [x] **Step 6: Commit**

```bash
git add lib/features/driver_licence/domain test/features/driver_licence
git commit -m "feat(licence): map a scan session onto the two licence sides"
```

---

### Task 3: The MethodChannel client

Platform channels ARE testable in Dart via a mock handler — so the client's error mapping gets real coverage even though the Swift does not.

**Files:**
- Create: `lib/core/data/attachments/scanner/native_document_scanner.dart`
- Modify: `lib/core/data/attachments/scanner/document_scanner.dart` (provider picks the native impl on iOS)
- Test: `test/core/data/attachments/scanner/native_document_scanner_test.dart`

**Interfaces:**
- Consumes: `DocumentScanner` (Task 1).
- Produces: `NativeDocumentScanner`; channel `hmm/document_scanner`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/scanner/native_document_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hmm/document_scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void mock(Future<Object?>? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  test('a scan becomes one PickedImageBytes per page, in order', () async {
    mock((call) async {
      if (call.method == 'scan') {
        return <Uint8List>[
          Uint8List.fromList([1]),
          Uint8List.fromList([2]),
        ];
      }
      return null;
    });

    final pages = await const NativeDocumentScanner().scan();

    expect(pages, hasLength(2));
    expect(pages[0].bytes, Uint8List.fromList([1]));
    expect(pages[1].bytes, Uint8List.fromList([2]));
    expect(pages[0].contentType, 'image/jpeg');
  });

  test('cancelling returns no pages rather than throwing', () async {
    mock((call) async => <Uint8List>[]);
    expect(await const NativeDocumentScanner().scan(), isEmpty);
  });

  test('an unavailable scanner is not an error', () async {
    // The UI hides the action on isAvailable() == false; a throw here would
    // surface a crash for a device that simply cannot scan.
    mock((call) async => throw PlatformException(code: 'unavailable'));

    expect(await const NativeDocumentScanner().isAvailable(), isFalse);
    expect(await const NativeDocumentScanner().scan(), isEmpty);
  });

  test('a real failure propagates', () async {
    mock((call) async =>
        throw PlatformException(code: 'failed', message: 'camera exploded'));

    expect(() => const NativeDocumentScanner().scan(),
        throwsA(isA<PlatformException>()));
  });

  test('isAvailable passes the platform answer through', () async {
    mock((call) async => call.method == 'isAvailable' ? true : null);
    expect(await const NativeDocumentScanner().isAvailable(), isTrue);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/data/attachments/scanner/native_document_scanner_test.dart`
Expected: FAIL — `native_document_scanner.dart` does not exist.

- [ ] **Step 3: Write the client**

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../picker/image_byte_source.dart';
import 'document_scanner.dart';

/// Talks to `ios/Runner/DocumentScannerPlugin.swift`.
///
/// Bytes cross the channel, never a file path: a path would mean a plaintext
/// JPEG of an identity document sitting in the app's tmp directory, outside
/// the vault, until the OS reclaimed it.
class NativeDocumentScanner implements DocumentScanner {
  const NativeDocumentScanner();

  static const _channel = MethodChannel('hmm/document_scanner');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      // Cannot scan is not a failure to report — it is a reason to offer the
      // plain camera instead.
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<PickedImageBytes>> scan() async {
    try {
      final pages = await _channel.invokeListMethod<Uint8List>('scan') ?? [];
      var i = 0;
      return [
        for (final bytes in pages)
          PickedImageBytes(
            bytes: bytes,
            originalName: 'scan-${++i}.jpg',
            contentType: 'image/jpeg',
          ),
      ];
    } on PlatformException catch (e) {
      if (e.code == 'unavailable' || e.code == 'already_presenting') {
        return const [];
      }
      rethrow;
    } on MissingPluginException {
      return const [];
    }
  }
}
```

- [ ] **Step 4: Point the provider at it on iOS**

In `document_scanner.dart`:

```dart
final documentScannerProvider = Provider<DocumentScanner>((ref) {
  // Android keeps the plain camera until its ML Kit half is written; the
  // interface is what makes that a one-line change later.
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return const NativeDocumentScanner();
  }
  return const UnavailableDocumentScanner();
});
```

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/core/data/attachments/scanner/`
Expected: PASS (6 tests)

- [ ] **Step 6: Mutation-check**

Change the `unavailable` branch in `scan()` to `rethrow`. Expected: the unavailable test fails. Restore.
Reverse the page loop. Expected: the ordering test fails. Restore.

- [ ] **Step 7: Commit**

```bash
git add lib/core/data/attachments/scanner test/core/data/attachments/scanner
git commit -m "feat(scanner): add the MethodChannel client"
```

---

### Task 4: The iOS plugin

Nothing here is testable. Keep it correspondingly boring.

**Files:**
- Create: `ios/Runner/DocumentScannerPlugin.swift`
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Write the plugin**

```swift
import Flutter
import UIKit
import VisionKit

/// Presents VisionKit's document camera and returns JPEG bytes per page.
///
/// Deliberately knows nothing about licences, sides or page limits: those
/// rules live in Dart where they can be tested. This file cannot be, and does
/// not even run on the simulator.
class DocumentScannerPlugin: NSObject {
  private var pendingResult: FlutterResult?

  static func register(with controller: FlutterViewController) {
    let instance = DocumentScannerPlugin()
    let channel = FlutterMethodChannel(
      name: "hmm/document_scanner",
      binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak controller] call, result in
      guard let controller = controller else { return }
      instance.handle(call, result: result, controller: controller)
    }
    // Retained by the channel's closure above.
    objc_setAssociatedObject(controller, "DocumentScannerPlugin", instance, .OBJC_ASSOCIATION_RETAIN)
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult,
    controller: FlutterViewController
  ) {
    switch call.method {
    case "isAvailable":
      result(VNDocumentCameraViewController.isSupported)

    case "scan":
      guard VNDocumentCameraViewController.isSupported else {
        result(FlutterError(code: "unavailable", message: "No document camera", details: nil))
        return
      }
      guard pendingResult == nil else {
        result(FlutterError(code: "already_presenting", message: "Scan in progress", details: nil))
        return
      }
      pendingResult = result
      let scanner = VNDocumentCameraViewController()
      scanner.delegate = self
      controller.present(scanner, animated: true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func finish(_ value: Any?) {
    pendingResult?(value)
    pendingResult = nil
  }
}

extension DocumentScannerPlugin: VNDocumentCameraViewControllerDelegate {
  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    var pages: [FlutterStandardTypedData] = []
    for index in 0..<scan.pageCount {
      if let data = scan.imageOfPage(at: index).jpegData(compressionQuality: 0.85) {
        pages.append(FlutterStandardTypedData(bytes: data))
      }
    }
    controller.dismiss(animated: true)
    finish(pages)
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    finish([])
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    controller.dismiss(animated: true)
    finish(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
  }
}
```

- [ ] **Step 2: Register it**

In `ios/Runner/AppDelegate.swift`, inside `application(_:didFinishLaunchingWithOptions:)`, before `GeneratedPluginRegistrant.register(with: self)` returns:

```swift
if let controller = window?.rootViewController as? FlutterViewController {
  DocumentScannerPlugin.register(with: controller)
}
```

- [ ] **Step 3: Build it**

Run: `flutter build ios --release --dart-define=API_ENV=production --dart-define=ONEDRIVE_CLIENT_ID=3056e225-6965-4c36-8542-db02f614e084`
Expected: build succeeds. A Swift compile error here is the only feedback this file gets.

- [ ] **Step 4: Commit**

```bash
git add ios/Runner
git commit -m "feat(scanner): add the VisionKit plugin"
```

---

### Task 5: The scan action on the licence screen

**Files:**
- Modify: `lib/features/driver_licence/presentation/screens/driver_licence_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/driver_licence/driver_licence_screen_test.dart`

**Interfaces:**
- Consumes: `documentScannerProvider` (Task 3), `LicenceScanPages` (Task 2), `ensureVaultUnlocked` (existing).

- [ ] **Step 1: Add the strings**

`app_en.arb`:
```json
"licenceScan": "Scan licence",
"licenceScanExtraPagesIgnored": "Only the first two pages were used."
```

`app_zh.arb`:
```json
"licenceScan": "扫描驾驶证",
"licenceScanExtraPagesIgnored": "仅使用了前两页。"
```

Unreviewed Chinese, like the rest of that file.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

```dart
class _FakeScanner implements DocumentScanner {
  _FakeScanner({this.available = true, this.pages = const []});
  final bool available;
  final List<PickedImageBytes> pages;
  int scans = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<PickedImageBytes>> scan() async {
    scans++;
    return pages;
  }
}
```

Assert, mounting the screen with that fake injected through `documentScannerProvider`:

- the scan action is present when `isAvailable()` is true
- **it is absent when `isAvailable()` is false** — not silently reinterpreted as a plain camera
- a two-page scan fills both slots, front from page 1
- a one-page scan fills only the front
- a four-page scan fills both and shows `licenceScanExtraPagesIgnored`
- a cancelled scan (empty list) changes nothing and shows no message
- **with the vault locked, the scanner is never opened** — assert `fake.scans == 0` and that the unlock path ran

- [ ] **Step 3: Run them and watch them fail**

Run: `flutter test test/features/driver_licence/driver_licence_screen_test.dart`
Expected: FAIL — no scan action exists.

- [ ] **Step 4: Wire it up**

In `build`, beside the existing capture slots:

```dart
if (scannerAvailable)
  OutlinedButton.icon(
    key: const Key('licenceScanButton'),
    icon: const Icon(Icons.document_scanner_outlined),
    label: Text(l.licenceScan),
    onPressed: _scan,
  ),
```

`scannerAvailable` comes from a `FutureProvider` wrapping `isAvailable()`, defaulting to false while it resolves — an action that appears a beat late is better than one that appears and cannot work.

```dart
Future<void> _scan() async {
  // Before the scanner opens, not after: scanning and then losing the result
  // is the bug fixed in 457cbf7.
  if (!await ensureVaultUnlocked(context, ref)) return;
  if (!mounted) return;

  final pages = LicenceScanPages.fromScan(
      await ref.read(documentScannerProvider).scan());
  if (!mounted || (pages.front == null && pages.back == null)) return;

  setState(() {
    if (pages.front != null) _newFront = pages.front;
    if (pages.back != null) _newBack = pages.back;
  });

  if (pages.ignoredPageCount > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.licenceScanExtraPagesIgnored)),
    );
  }
}
```

Note the pages become PENDING picks. Nothing reaches the vault until Save, exactly as the camera path already behaves.

- [ ] **Step 5: Run them and watch them pass**

Run: `flutter test test/features/driver_licence/`
Expected: PASS

- [ ] **Step 6: Mutation-check**

Render the scan button unconditionally. Expected: the unavailable test fails. Restore.
Move `ensureVaultUnlocked` to after the `scan()` call. Expected: the locked-vault test fails. Restore.
Assign `pages.back` to `_newFront`. Expected: the two-page test fails. Restore.

- [ ] **Step 7: Commit**

```bash
flutter analyze
git add lib test
git commit -m "feat(licence): scan both sides in one session"
```

---

### Task 6: Verification

- [ ] **Step 1: Analyzer** — `flutter analyze`. Expected: only the 2 pre-existing issues (`onboarding_screen.dart`, `main.dart`).
- [ ] **Step 2: Full suite** — `flutter test`. Expected: all pass. It stood at 1506 before this work.
- [ ] **Step 3: ARB parity**

```bash
python3 -c "
import json
en = json.load(open('lib/l10n/app_en.arb')); zh = json.load(open('lib/l10n/app_zh.arb'))
ek = {k for k in en if not k.startswith('@')}; zk = {k for k in zh if not k.startswith('@')}
print('en', len(ek), 'zh', len(zk)); print(sorted(ek-zk), sorted(zk-ek))
"
```
Expected: equal counts, both lists empty.

- [ ] **Step 4: ON DEVICE — the only real proof.** Deploy with `scripts/deploy-prod-ios-device.sh`, then:
  - Tap **Scan licence**. VisionKit opens with live edge detection.
  - Shoot the front, then the back, then Save.
  - **Both slots fill, front is the front**, each cropped to the card, upright and legible — not the portrait phone photo this feature exists to replace.
  - Save, reopen the screen, confirm both persist.
  - Cancel a scan and confirm nothing changes.

  None of this can be tested: VisionKit does not run on the simulator.

- [ ] **Step 5: Commit**

```bash
git add -A lib test docs && git commit -m "chore(scanner): verify analyzer, suite and en/zh parity"
```

---

## Out of scope

- **OCR extraction** — reading fields off the scan into the licence note. The next piece; `receipt_scan`'s `ReceiptExtractor` is the pattern, on-device only for identity documents.
- **Android** — same interface, ML Kit's `GmsDocumentScanning`. `isAvailable()` returns false until then, so Android keeps today's camera with no regression.
- **Registration scans, health card, passport** — the same scanner once the licence works end to end.
- **PDF output.** VisionKit can produce one; nothing needs it yet.

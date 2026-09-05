# Document Scanner — Design

**Status:** approved 2026-09-04, not implemented.
**Scope:** licence capture only. Registration scans, other IDs and receipts follow later.

## Goal

Replace the plain camera for identity-document capture with the OS document
scanner, so a licence photo comes out cropped to the card, deskewed and
de-shadowed — landscape, readable, and fit to hold up to someone who asked to
see it.

## Why not AI

"Use AI to clean up the photo" is the wrong tool. Deskew, shadow removal and
crop-to-card are classical computer vision; an LLM describes an image, it does
not reliably return a cleaned one. Both platforms ship exactly this natively —
VisionKit on iOS, ML Kit's document scanner on Android — free, offline, and
without the image leaving the device. For a document we deliberately encrypt at
rest, "without leaving the device" is not a nice-to-have.

This also fixes the reported "image is portrait, licence is landscape" problem
as a side effect: the scanner crops to the detected card, whatever the phone's
orientation was.

## Decisions

| Decision | Chosen | Why |
|---|---|---|
| How to reach the OS scanner | Native `MethodChannel`, iOS first | No third-party code in the path that handles licences and passports. Matches CLAUDE.md's iOS-primary stance. Android follows behind the same Dart interface. |
| Capture flow | One session, both sides | Fewer taps, and both sides come out under identical lighting and framing. |
| Channel payload | Bytes, not file paths | A file path means a plaintext JPEG of an identity document in the app's tmp directory, outside the vault. |

## Architecture

### The seam

`lib/core/data/attachments/scanner/document_scanner.dart`:

```dart
abstract interface class DocumentScanner {
  /// False on the simulator, on Android until its half lands, and on old OS.
  Future<bool> isAvailable();

  /// One entry per page, in capture order. Empty when the user cancels.
  Future<List<PickedImageBytes>> scan();
}
```

Returns the EXISTING `PickedImageBytes`, so the pending-pick model,
`persistToVault(sensitive: true)` and downsizing all work unchanged. The licence
screen gains a scan path; it gains no new plumbing.

Implementations:
- `NativeDocumentScanner` — the MethodChannel.
- Tests inject a fake through `documentScannerProvider`, the same way
  `imageByteSourceProvider` is already overridden.

### Channel contract

Channel name: `hmm/document_scanner`

| Method | Arguments | Returns |
|---|---|---|
| `isAvailable` | — | `bool` |
| `scan` | — | `List<Uint8List>` (JPEG); `[]` when cancelled |

Error codes, as `PlatformException`:

| Code | Meaning | Dart response |
|---|---|---|
| `unavailable` | Scanner not supported here | Fall back to the camera picker. Not an error to the user. |
| `permission_denied` | Camera permission refused | Existing snackbar path. |
| `already_presenting` | A scan is already on screen | Ignore the second call. |
| `failed` | VisionKit reported an error | Surface the message. |

`NSCameraUsageDescription` is already declared in `ios/Runner/Info.plist`, and
the deployment target is 15.5 (VisionKit needs 13+), so neither needs changing.

### iOS implementation

`ios/Runner/DocumentScannerPlugin.swift` — the project's FIRST MethodChannel;
only `AppDelegate.swift` exists today. Registered from `AppDelegate`.

- Present `VNDocumentCameraViewController` from the root view controller.
- `documentCameraViewController(_:didFinishWith:)` — loop `scan.pageCount`,
  `scan.imageOfPage(at:)`, `jpegData(compressionQuality: 0.85)`.
- `documentCameraViewControllerDidCancel` — return `[]`.
- `documentCameraViewController(_:didFailWithError:)` — `failed`.
- `isAvailable` — `VNDocumentCameraViewController.isSupported`.

**The Swift stays deliberately dumb: present, collect, encode, nothing else.**
It cannot be unit-tested and does not run on the simulator, so every rule that
could be wrong lives in Dart where a test can reach it. This is the main
constraint on the split, not an incidental style choice.

## Licence screen flow

A "Scan licence" action opens one session for both sides.

| Pages returned | Result |
|---|---|
| 0 (cancelled) | Nothing changes. No message — the user chose this. |
| 1 | Front. |
| 2 | Front, back. |
| 3+ | First two used; tell the user the rest were ignored. |

- Pages become PENDING picks, written to the vault only on Save — same as the
  current capture, so leaving the screen still costs nothing.
- The per-slot camera stays, for replacing one side.
- `ensureVaultUnlocked()` runs BEFORE the scanner opens. Scanning and then
  losing the result is exactly the bug fixed in `457cbf7`.
- When `isAvailable()` is false, fall back to the existing camera picker
  silently. Android and the simulator keep working with no regression.

## Testing

Covered, by injecting a fake scanner:
- each page-count mapping in the table above
- cancel changes nothing
- `isAvailable() == false` falls back to the camera picker
- a locked vault is resolved before the scanner opens, not after

NOT covered, and no test can be: VisionKit itself and the Swift. There is no
simulator support. The first real proof is on a device — scan a licence, check
both sides are cropped, upright and readable.

## Out of scope

- **OCR extraction** — reading fields off the scan and filling the licence note.
  The next piece; `receipt_scan`'s `ReceiptExtractor` is the pattern, on-device
  only for identity documents.
- **Android** — same interface, ML Kit's `GmsDocumentScanning` later.
  `isAvailable()` returns false until then.
- **Registration scans, health card, passport** — the same scanner, once the
  licence works end to end. Generalising from one consumer produces the wrong
  abstraction; the contact block is the local evidence for waiting.
- **PDF output.** VisionKit can produce one; nothing needs it yet.

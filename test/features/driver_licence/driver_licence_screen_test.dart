import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/features/driver_licence/data/i_driver_licence_repository.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/driver_licence/presentation/screens/driver_licence_screen.dart';
import 'package:hmm_console/features/driver_licence/presentation/screens/licence_show_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const front = VaultRef(
  path: 'attachments/note-1/sensitive/front.jpg',
  contentType: 'image/jpeg',
  byteSize: 100,
  sensitive: true,
);
const back = VaultRef(
  path: 'attachments/note-1/sensitive/back.jpg',
  contentType: 'image/jpeg',
  byteSize: 100,
  sensitive: true,
);

class _StubVault extends VaultSessionController {
  _StubVault(this._status);
  final VaultStatus _status;
  @override
  VaultStatus build() => _status;
}

/// Locked until the unlock FLOW runs — refresh alone does not open it. That
/// is what separates "resolve the status" from "actually unlock", and only the
/// second lets a capture proceed.
class _UnlockableVault extends VaultSessionController {
  @override
  VaultStatus build() => VaultStatus.locked;

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> unlockWithBiometric() async {
    state = VaultStatus.unlocked;
    return true;
  }
}

class _RecordingByteSource implements ImageByteSource {
  int picks = 0;

  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async {
    picks++;
    return null;
  }
}

/// Mirrors the real controller: build() cannot await, so it starts `locked`
/// and only refresh() reveals that the vault is actually open.
class _NeedsRefreshVault extends VaultSessionController {
  static int refreshes = 0;

  @override
  VaultStatus build() => VaultStatus.locked;

  @override
  Future<void> refresh() async {
    refreshes++;
    state = VaultStatus.unlocked;
  }
}

class _ThrowingRepo implements IDriverLicenceRepository {
  @override
  Future<DriverLicence?> getLicence() async =>
      throw UnimplementedError('driver licence has no cloudApi repository');
  @override
  Future<int?> noteId() async => null;
  @override
  Future<DriverLicence> saveLicence(DriverLicence l) async =>
      throw UnimplementedError('driver licence has no cloudApi repository');
}

/// Never completes its read, standing in for the slow path: in cloudStorage
/// the read goes through the author future and the sync-aware note repository.
class _SlowRepo implements IDriverLicenceRepository {
  final _never = Completer<DriverLicence?>();

  @override
  Future<DriverLicence?> getLicence() => _never.future;
  @override
  Future<int?> noteId() async => 1;
  @override
  Future<DriverLicence> saveLicence(DriverLicence l) async => l;
}

class _FakeRepo implements IDriverLicenceRepository {
  _FakeRepo([this._stored]);
  DriverLicence? _stored;

  final saves = <DriverLicence>[];

  /// Holds a save in flight, so a second tap lands while the first is still
  /// running — which is the only situation the re-entrancy guard is for.
  Duration saveDelay = Duration.zero;

  @override
  Future<DriverLicence?> getLicence() async => _stored;

  @override
  Future<int?> noteId() async => _stored == null ? null : 1;

  @override
  Future<DriverLicence> saveLicence(DriverLicence licence) async {
    if (saveDelay > Duration.zero) await Future<void>.delayed(saveDelay);
    saves.add(licence);
    _stored = licence;
    return licence;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeRepo repo,
      {VaultStatus vault = VaultStatus.unlocked}) async {
    // The form is taller than the default 600px test viewport, so the save
    // button sits off-screen and cannot be tapped.
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverLicenceRepositoryModeProvider.overrideWithValue(repo),
        vaultSessionProvider.overrideWith(() => _StubVault(vault)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DriverLicenceScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('nothing saved shows the empty label and a capture prompt',
      (tester) async {
    await pump(tester, _FakeRepo());

    expect(find.byKey(const Key('licenceEmptyLabel')), findsOneWidget);
    expect(find.text('Capture front'), findsOneWidget);
    expect(find.text('Capture back'), findsOneWidget);
  });

  testWidgets('a saved licence renders every detail', (tester) async {
    await pump(
      tester,
      _FakeRepo(DriverLicence(
        number: 'D1234-56789',
        licenceClass: 'G',
        jurisdiction: 'Ontario',
        issuedDate: DateTime.utc(2020, 5, 1),
        expiryDate: DateTime.utc(2030, 5, 1),
      )),
    );

    expect(find.text('D1234-56789'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Ontario'), findsOneWidget);
    expect(find.text('2020-05-01'), findsOneWidget);
    expect(find.text('2030-05-01'), findsOneWidget);
    expect(find.byKey(const Key('licenceEmptyLabel')), findsNothing);
  });

  testWidgets('both sides get their own labelled slot', (tester) async {
    await pump(tester, _FakeRepo(const DriverLicence(
      frontImage: front,
      backImage: back,
    )));

    expect(find.byKey(const Key('licenceFrontSlot')), findsOneWidget);
    expect(find.byKey(const Key('licenceBackSlot')), findsOneWidget);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('a front-only licence shows the front and an empty back slot',
      (tester) async {
    await pump(tester, _FakeRepo(const DriverLicence(frontImage: front)));

    // The stored side must NOT read as "capture me" — that invites the user
    // to overwrite a photo they already have.
    expect(find.text('Capture front'), findsNothing);
    expect(find.text('Capture back'), findsOneWidget);
  });

  testWidgets('editing a field and saving preserves the images',
      (tester) async {
    final repo = _FakeRepo(const DriverLicence(
      number: 'OLD',
      frontImage: front,
      backImage: back,
    ));
    await pump(tester, repo);

    await tester.enterText(
        find.byKey(const Key('licenceNumberField')), 'NEW-NUMBER');
    await tester.tap(find.byKey(const Key('licenceSaveButton')));
    await tester.pump();
    await tester.pump();

    expect(repo.saves, hasLength(1));
    expect(repo.saves.single.number, 'NEW-NUMBER');
    // A details-only save must not drop the photos.
    expect(repo.saves.single.frontImage, front);
    expect(repo.saves.single.backImage, back);
  });

  testWidgets('a double-tapped save writes once', (tester) async {
    // A second tap while the first is in flight has created duplicate records
    // in this codebase before; here it would also persist the same bytes twice.
    final repo = _FakeRepo(const DriverLicence(number: 'X'))
      ..saveDelay = const Duration(milliseconds: 50);
    await pump(tester, repo);

    // tester.tap drains microtasks, so without a genuinely slow save the
    // first one finishes before the second tap and this would prove nothing.
    final button = find.byKey(const Key('licenceSaveButton'));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(repo.saves, hasLength(1));
  });

  testWidgets('the show action appears only once there is an image',
      (tester) async {
    await pump(tester, _FakeRepo(const DriverLicence(number: 'X')));
    expect(find.byKey(const Key('showLicenceAction')), findsNothing);

    await pump(tester, _FakeRepo(const DriverLicence(frontImage: front)));
    expect(find.byKey(const Key('showLicenceAction')), findsOneWidget);
  });

  testWidgets('a failed read says so, instead of claiming nothing is saved',
      (tester) async {
    // The bug this exists for: the error left `value` null, so the screen
    // showed "No licence saved yet" — indistinguishable from an empty one, and
    // it sent the user off to re-enter details that were never rejected aloud.
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverLicenceRepositoryModeProvider.overrideWithValue(_ThrowingRepo()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DriverLicenceScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('licenceErrorLabel')), findsOneWidget);
    expect(find.byKey(const Key('licenceEmptyLabel')), findsNothing);
  });

  testWidgets('a read still in flight does NOT claim there is no licence',
      (tester) async {
    // The reported bug: opening the screen announced "No licence saved yet"
    // before the read returned, over a licence that was there all along.
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverLicenceRepositoryModeProvider.overrideWithValue(_SlowRepo()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DriverLicenceScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('licenceLoading')), findsOneWidget);
    expect(find.byKey(const Key('licenceEmptyLabel')), findsNothing);
  });

  testWidgets('a locked vault explains itself once, above the slots',
      (tester) async {
    // Not twice, once per slot: the same sentence side by side is noise, and
    // the full notice overflows a 120px image slot outright.
    await pump(
      tester,
      _FakeRepo(const DriverLicence(frontImage: front, backImage: back)),
      vault: VaultStatus.locked,
    );

    expect(find.byKey(const Key('licenceVaultLockedNotice')), findsOneWidget);
    expect(find.byKey(const Key('licenceVaultLockedSlot')), findsNWidgets(2));
    // And the slots must NOT invite a re-capture over photos that exist.
    expect(find.text('Capture front'), findsNothing);
  });

  testWidgets('the primary button says Save, not Edit', (tester) async {
    // Reported as "edit licence button no action": it SAVES, but calling it
    // "Edit licence" described the screen you were already on, so tapping it
    // looked like nothing happened.
    await pump(tester, _FakeRepo(const DriverLicence(number: 'X')));

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Edit licence'), findsNothing);
  });

  testWidgets('with no licence yet the button invites adding one',
      (tester) async {
    await pump(tester, _FakeRepo());

    expect(find.text('Add licence'), findsOneWidget);
  });

  testWidgets('saving confirms it happened', (tester) async {
    await pump(tester, _FakeRepo(const DriverLicence(number: 'X')));

    await tester.tap(find.byKey(const Key('licenceSaveButton')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Licence saved'), findsOneWidget);
  });

  testWidgets('tapping a stored photo opens it instead of re-capturing',
      (tester) async {
    // The whole tile used to be a capture target, so an existing photo could
    // never be opened and the obvious gesture overwrote it.
    await pump(tester, _FakeRepo(const DriverLicence(frontImage: front)));

    await tester.tap(find.byKey(const Key('licenceFrontSlot')));
    // Bounded pumps, not pumpAndSettle: with no resolver stubbed the show
    // screen spins forever and settling would never return.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LicenceShowScreen), findsOneWidget);
  });

  testWidgets('replacing a photo stays available as its own target',
      (tester) async {
    await pump(tester, _FakeRepo(const DriverLicence(frontImage: front)));

    expect(find.byKey(const Key('licenceFrontSlot-replace')), findsOneWidget);
    // An empty slot has no replace button — the tile itself captures.
    expect(find.byKey(const Key('licenceBackSlot-replace')), findsNothing);
  });

  testWidgets('a locked vault makes the slot neither viewable nor a capture',
      (tester) async {
    await pump(tester, _FakeRepo(const DriverLicence(frontImage: front)),
        vault: VaultStatus.locked);

    // Nothing to open (it cannot be decrypted) and no replace affordance
    // over a photo the user cannot even see.
    expect(find.byKey(const Key('licenceFrontSlot-replace')), findsNothing);
  });

  testWidgets('the screen resolves the real vault state on entry',
      (tester) async {
    // The reported bug: the vault was unlocked in Settings, but the licence
    // screen still refused to capture. VaultSessionController.build() cannot
    // await, so it reports `locked` until a caller refreshes — and this screen
    // never did, so it was locked forever no matter what the vault was doing.
    _NeedsRefreshVault.refreshes = 0;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverLicenceRepositoryModeProvider
            .overrideWithValue(_FakeRepo(const DriverLicence(frontImage: front))),
        vaultSessionProvider.overrideWith(_NeedsRefreshVault.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DriverLicenceScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(_NeedsRefreshVault.refreshes, greaterThan(0),
        reason: 'without refresh() the status is a stale default');
    // And having resolved, it stops claiming the photo is locked away.
    expect(find.byKey(const Key('licenceVaultLockedNotice')), findsNothing);
  });

  testWidgets('capture unlocks the vault rather than just refusing',
      (tester) async {
    // Reading the status and bailing is not enough: the vault can be opened,
    // and the user tapping "capture" has said they want to. Merely reporting
    // "locked" is the dead end that was reported.
    final source = _RecordingByteSource();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverLicenceRepositoryModeProvider.overrideWithValue(_FakeRepo()),
        vaultSessionProvider.overrideWith(_UnlockableVault.new),
        imageByteSourceProvider.overrideWithValue(source),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DriverLicenceScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('licenceFrontSlot')));
    await tester.pump();
    await tester.pump();

    expect(source.picks, 1,
        reason: 'the camera should open once the vault has been unlocked');
  });
}

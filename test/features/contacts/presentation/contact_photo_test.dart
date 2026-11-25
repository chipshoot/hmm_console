import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/contacts/presentation/widgets/contact_photo.dart';
import 'package:hmm_console/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

const _jane = Contact(
  id: 'j1',
  contactType: ContactType.person,
  firstName: 'Jane',
  lastName: 'Smith',
);

const _ref = VaultRef(
  path: 'n/1/a.jpg',
  contentType: 'image/jpeg',
  byteSize: 5,
);

// 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _Bytes implements ImageByteSource {
  _Bytes({this.result, this.error});
  final PickedImageBytes? result;
  final Object? error;
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async {
    if (error != null) throw error!;
    return result;
  }
}

List<Override> _overrides(
  InMemoryContactRepository repo, {
  ImageByteSource? bytes,
}) => [
  contactRepositoryModeProvider.overrideWithValue(repo),
  imageByteSourceProvider.overrideWithValue(bytes ?? _Bytes()),
  // Never resolves: a stored photo shows its initials placeholder.
  attachmentResolverProvider.overrideWith((ref) => Completer<Never>().future),
];

Widget _app(
  List<Override> overrides,
  Widget home, {
  TargetPlatform? platform,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: ThemeData(platform: platform ?? TargetPlatform.android),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

ContactPhoto _photoOfSize(WidgetTester tester, double size) => tester
    .widgetList<ContactPhoto>(find.byType(ContactPhoto))
    .firstWhere((p) => p.size == size);

void main() {
  group('ContactPhoto', () {
    testWidgets('no photo shows initials', (tester) async {
      await tester.pumpWidget(
        _app(
          _overrides(InMemoryContactRepository()),
          const Scaffold(body: ContactPhoto(contact: _jane, size: 40)),
        ),
      );
      expect(find.text('JS'), findsOneWidget);
    });

    testWidgets('pending bytes show as a memory image', (tester) async {
      await tester.pumpWidget(
        _app(
          _overrides(InMemoryContactRepository()),
          Scaffold(
            body: ContactPhoto(
              contact: _jane,
              size: 40,
              pending: PickedImageBytes(bytes: _png, originalName: 'a.png'),
            ),
          ),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<MemoryImage>());
    });

    testWidgets('a removed photo shows initials', (tester) async {
      await tester.pumpWidget(
        _app(
          _overrides(InMemoryContactRepository()),
          Scaffold(
            body: ContactPhoto(
              contact: _jane.copyWith(photo: _ref),
              size: 40,
              removed: true,
            ),
          ),
        ),
      );
      expect(find.text('JS'), findsOneWidget);
    });
  });

  testWidgets('a list row shows the photo circle at 40', (tester) async {
    await tester.pumpWidget(
      _app(
        _overrides(InMemoryContactRepository()),
        Scaffold(
          body: ContactTile(contact: _jane, onTap: () {}),
        ),
      ),
    );
    expect(_photoOfSize(tester, 40), isNotNull);
    expect(find.text('JS'), findsOneWidget);
  });

  testWidgets('the contact screen shows the photo at 120 above the name', (
    tester,
  ) async {
    final repo = InMemoryContactRepository()..seed(_jane);
    await tester.pumpWidget(
      _app(_overrides(repo), const ContactDetailScreen(contactId: 'j1')),
    );
    await tester.pumpAndSettle();
    expect(_photoOfSize(tester, 120), isNotNull);
    final photoY = tester.getCenter(find.byType(ContactPhoto)).dy;
    final nameY = tester.getCenter(find.text('Jane Smith').first).dy;
    expect(photoY, lessThan(nameY));
  });

  group('edit screen', () {
    Future<void> mount(
      WidgetTester tester, {
      Contact seed = _jane,
      ImageByteSource? bytes,
    }) async {
      final repo = InMemoryContactRepository()..seed(seed);
      await tester.pumpWidget(
        _app(
          _overrides(repo, bytes: bytes),
          ContactEditScreen(contactId: seed.id),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('contact-photo-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('no photo: Choose, Take, Cancel and no Remove', (tester) async {
      await mount(tester);
      await openSheet(tester);
      expect(find.text(_l.contactPhotoChoose), findsOneWidget);
      expect(find.text(_l.contactPhotoTake), findsOneWidget);
      expect(find.text(_l.commonCancel), findsOneWidget);
      expect(find.text(_l.contactPhotoRemove), findsNothing);
    });

    testWidgets('with a photo, Remove photo shows initials', (tester) async {
      await mount(tester, seed: _jane.copyWith(photo: _ref));
      await openSheet(tester);
      await tester.tap(find.text(_l.contactPhotoRemove));
      await tester.pumpAndSettle();
      final photo = _photoOfSize(tester, 120);
      expect(photo.removed, isTrue);
      expect(find.text('JS'), findsWidgets);
    });

    testWidgets('choosing a photo shows it before save', (tester) async {
      await mount(
        tester,
        bytes: _Bytes(
          result: PickedImageBytes(bytes: _png, originalName: 'a.png'),
        ),
      );
      await openSheet(tester);
      await tester.tap(find.text(_l.contactPhotoChoose));
      await tester.pumpAndSettle();
      expect(_photoOfSize(tester, 120).pending, isNotNull);
    });

    testWidgets('a picker refusal shows its message and keeps the form', (
      tester,
    ) async {
      await mount(
        tester,
        // A real pick never throws; the size check at pick refuses it.
        bytes: _Bytes(
          result: PickedImageBytes(
            bytes: Uint8List(kMaxAttachmentBytes + 1),
            originalName: 'big.jpg',
            contentType: 'image/jpeg',
          ),
        ),
      );
      await openSheet(tester);
      await tester.tap(find.text(_l.contactPhotoChoose));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('max is $kMaxAttachmentBytes'),
        findsOneWidget,
      );
      expect(_photoOfSize(tester, 120).pending, isNull);
      expect(find.byType(ContactEditScreen), findsOneWidget);
    });

    testWidgets('any other picker error shows the generic message', (
      tester,
    ) async {
      await mount(tester, bytes: _Bytes(error: StateError('boom')));
      await openSheet(tester);
      await tester.tap(find.text(_l.contactPhotoChoose));
      await tester.pumpAndSettle();
      expect(find.text(_l.contactPhotoPickFailed), findsOneWidget);
    });
  });
}

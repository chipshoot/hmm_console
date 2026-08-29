import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/driver_licence/data/driver_licence_codec.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';

void main() {
  const front = VaultRef(
      path: 'attachments/note-1/front.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
      sensitive: true);
  const back = VaultRef(
      path: 'attachments/note-1/back.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
      sensitive: true);

  final attachments = NoteAttachments(images: const [front, back]);

  DriverLicence full() => DriverLicence(
        number: 'D1234-56789',
        licenceClass: 'G',
        jurisdiction: 'Ontario',
        issuedDate: DateTime.utc(2020, 5, 1),
        expiryDate: DateTime.utc(2030, 5, 1),
        frontImage: front,
        backImage: back,
      );

  test('round-trips a fully populated licence', () {
    expect(
      DriverLicenceCodec.fromMap(DriverLicenceCodec.toMap(full()), attachments),
      full(),
    );
  });

  test('round-trips a licence with only an expiry date', () {
    final sparse = DriverLicence(expiryDate: DateTime.utc(2030, 5, 1));
    expect(
      DriverLicenceCodec.fromMap(
          DriverLicenceCodec.toMap(sparse), NoteAttachments.empty),
      sparse,
    );
  });

  test('content records PATHS, not the refs themselves', () {
    // The bytes must be referenced from the attachments column so VaultGc sees
    // them; content only says which side each path is.
    final map = DriverLicenceCodec.toMap(full());
    expect(map['frontImagePath'], front.path);
    expect(map['backImagePath'], back.path);
    expect(map.containsKey('frontImage'), isFalse);
  });

  test('resolves each side from the attachments column by path', () {
    final decoded =
        DriverLicenceCodec.fromMap(DriverLicenceCodec.toMap(full()), attachments);
    expect(decoded.frontImage, front);
    expect(decoded.backImage, back);
  });

  test('a path with no matching attachment resolves to null, not a throw', () {
    // The mapping outlived the bytes; the rest of the licence must still read.
    final decoded = DriverLicenceCodec.fromMap(
        DriverLicenceCodec.toMap(full()), NoteAttachments.empty);
    expect(decoded.frontImage, isNull);
    expect(decoded.number, 'D1234-56789');
  });

  test('an attachment with no mapping is left alone, not adopted as a side', () {
    final decoded = DriverLicenceCodec.fromMap({'number': 'X'}, attachments);
    expect(decoded.frontImage, isNull);
    expect(decoded.backImage, isNull);
  });

  test('stores class and jurisdiction as literals', () {
    final map = DriverLicenceCodec.toMap(full());
    expect(map['licenceClass'], 'G');
    expect(map['jurisdiction'], 'Ontario');
  });

  test('unknown fields survive an edit', () {
    final decoded = DriverLicenceCodec.fromMap(
        {'number': 'X', 'futureThing': 'keep me'}, NoteAttachments.empty);
    final resaved = DriverLicenceCodec.toMap(decoded);
    expect(resaved['futureThing'], 'keep me');
  });

  test('a malformed date does not take the licence down', () {
    final decoded = DriverLicenceCodec.fromMap(
        {'number': 'X', 'expiryDate': 'not-a-date'}, NoteAttachments.empty);
    expect(decoded.number, 'X');
    expect(decoded.expiryDate, isNull);
  });

  test('hasImages is false only when both sides are absent', () {
    expect(const DriverLicence().hasImages, isFalse);
    expect(DriverLicence(frontImage: front).hasImages, isTrue);
  });

  test('the image path keys never leak into extraFields', () {
    // Found by a surviving mutation: dropping them from _knownKeys broke
    // nothing, because == does not compare extraFields and the round-trip
    // still matched.
    final decoded =
        DriverLicenceCodec.fromMap(DriverLicenceCodec.toMap(full()), attachments);

    expect(decoded.extraFields, isEmpty);
  });

  test('a dangling path is dropped on resave, not resurrected', () {
    // The bytes are gone, so the mapping is worthless. If the path key leaked
    // into extraFields it would be written back out and the next read would
    // again claim a front image that cannot be opened.
    final decoded = DriverLicenceCodec.fromMap(
        DriverLicenceCodec.toMap(full()), NoteAttachments.empty);

    final resaved = DriverLicenceCodec.toMap(decoded);
    expect(resaved.containsKey('frontImagePath'), isFalse);
    expect(resaved.containsKey('backImagePath'), isFalse);
    expect(resaved['number'], 'D1234-56789');
  });
}

import 'dart:collection';

import '../../../core/data/attachments/attachment_ref.dart';

/// A driver's licence: the details on the card, plus a photo of each side.
///
/// One per person, stored as a single note rather than a list — a licence is
/// not something you have several of, and the show-it-to-an-officer flow wants
/// one obvious thing to open.
///
/// **The image bytes do NOT live here.** [frontImage] and [backImage] are
/// read-through projections of the owning note's `attachments` column, and the
/// note's CONTENT records only their paths. That split is load-bearing:
/// `VaultGc` builds its set of live files by reading every note's attachments
/// column, so bytes referenced only from content would be collected and the
/// user's licence photos silently deleted. See `DriverLicenceCodec`.
///
/// Both sides are stored `sensitive: true`, so they land in the encrypted
/// vault behind the same local-auth gate as other sensitive attachments.
class DriverLicence {
  const DriverLicence({
    this.number,
    this.licenceClass,
    this.jurisdiction,
    this.issuedDate,
    this.expiryDate,
    this.frontImage,
    this.backImage,
    Map<String, dynamic> extraFields = const {},
  }) : _extraFields = extraFields;

  final String? number;

  /// A STORED literal (`G`, `G2`, `Class 5`, ...), never a translated label.
  /// Classes are jurisdiction-specific and there is no useful global list, so
  /// this is free text rather than an enum.
  final String? licenceClass;

  final String? jurisdiction;
  final DateTime? issuedDate;
  final DateTime? expiryDate;

  /// Projections of the note's attachments column — see the class doc.
  final VaultRef? frontImage;
  final VaultRef? backImage;

  final Map<String, dynamic> _extraFields;

  /// Keys this version does not model, kept verbatim so an older client cannot
  /// destroy a newer one's data.
  ///
  /// Exposed unmodifiable: this map's entire job is preservation, so editing
  /// it through the getter must not be possible. A view rather than a copy, to
  /// keep the constructor const.
  Map<String, dynamic> get extraFields => UnmodifiableMapView(_extraFields);

  /// Whether there is anything to show. One side is enough — a licence
  /// photographed on the front only is still worth showing.
  bool get hasImages => frontImage != null || backImage != null;

  bool get isEmpty =>
      extraFields.isEmpty &&
      (number ?? '').trim().isEmpty &&
      (licenceClass ?? '').trim().isEmpty &&
      (jurisdiction ?? '').trim().isEmpty &&
      issuedDate == null &&
      expiryDate == null &&
      !hasImages;

  /// Deliberately NO copyWith. `number ?? this.number` cannot express "clear
  /// the number" — it is indistinguishable from "leave it alone", which fails
  /// silently with wrong data rather than loudly. Construct directly and say
  /// what every field should be, or use the `_kSentinel` pattern from
  /// `automobile_edit_screen.dart`.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverLicence &&
          other.number == number &&
          other.licenceClass == licenceClass &&
          other.jurisdiction == jurisdiction &&
          other.issuedDate == issuedDate &&
          other.expiryDate == expiryDate &&
          other.frontImage == frontImage &&
          other.backImage == backImage;

  @override
  int get hashCode => Object.hash(number, licenceClass, jurisdiction,
      issuedDate, expiryDate, frontImage, backImage);
}

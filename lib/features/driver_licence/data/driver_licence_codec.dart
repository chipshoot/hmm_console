import '../../../core/data/attachments/attachment_ref.dart';
import '../domain/driver_licence.dart';

/// `DriverLicence` <-> the JSON map stored in its note's content.
///
/// **The one rule that matters here:** content stores image PATHS, never
/// serialized refs. `VaultGc` decides what to delete by reading every note's
/// `attachments` column, so bytes referenced only from content are invisible
/// to it and get collected — the user opens their licence and the photos are
/// gone. Writing the ref into content would look like it worked and fail
/// weeks later, which is why a test pins it and a mutation proves that test.
class DriverLicenceCodec {
  const DriverLicenceCodec._();

  static const frontImagePathKey = 'frontImagePath';
  static const backImagePathKey = 'backImagePath';

  static const _knownKeys = <String>{
    'number',
    'licenceClass',
    'jurisdiction',
    'issuedDate',
    'expiryDate',
    frontImagePathKey,
    backImagePathKey,

  };

  static Map<String, dynamic> toMap(DriverLicence l) => {
        // Preserved keys first, so a typed field overwrites them.
        ...l.extraFields,
        if (l.number != null) 'number': l.number,
        if (l.licenceClass != null) 'licenceClass': l.licenceClass,
        if (l.jurisdiction != null) 'jurisdiction': l.jurisdiction,
        if (l.issuedDate != null)
          'issuedDate': l.issuedDate!.toIso8601String(),
        if (l.expiryDate != null)
          'expiryDate': l.expiryDate!.toIso8601String(),
        // Paths only. Never the refs.
        if (l.frontImage != null) frontImagePathKey: l.frontImage!.path,
        if (l.backImage != null) backImagePathKey: l.backImage!.path,
      };

  static DriverLicence fromMap(
    Map<String, dynamic> m,
    NoteAttachments attachments,
  ) {
    // Resolve each side against what the note actually holds. A path whose
    // bytes are gone yields null rather than throwing: the mapping can outlive
    // the file, and the rest of the licence must still read.
    final all = <VaultRef>[
      ...attachments.images.whereType<VaultRef>(),
      ...attachments.files.whereType<VaultRef>(),
    ];
    VaultRef? byPath(Object? raw) {
      final path = _str(raw);
      if (path == null) return null;
      for (final r in all) {
        if (r.path == path) return r;
      }
      return null;
    }

    return DriverLicence(
      number: _str(m['number']),
      licenceClass: _str(m['licenceClass']),
      jurisdiction: _str(m['jurisdiction']),
      issuedDate: _date(m['issuedDate']),
      expiryDate: _date(m['expiryDate']),
      frontImage: byPath(m[frontImagePathKey]),
      backImage: byPath(m[backImagePathKey]),
      extraFields: {
        for (final e in m.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  static String? _str(Object? v) => v is String ? v : null;

  /// Tolerant on purpose: persisted data may hold anything, and a parse error
  /// here would cost the whole licence rather than one field.
  static DateTime? _date(Object? v) {
    final s = _str(v);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }
}

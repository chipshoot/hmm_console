import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

ServiceRecord _record() => ServiceRecord(
      id: 1,
      automobileId: 7,
      date: DateTime(2026, 1, 2),
      mileage: 100,
      type: ServiceType.oilChange,
    );

void main() {
  test('attachments defaults to empty', () {
    expect(_record().attachments.isEmpty, isTrue);
  });

  test('copyWith sets attachments and preserves other fields', () {
    const ref = VaultRef(
      path: 'attachments/note-1/a.jpg',
      contentType: 'image/jpeg',
      byteSize: 10,
    );
    final updated = _record().copyWith(
      attachments: NoteAttachments(images: const [ref]),
    );
    expect(updated.attachments.images, [ref]);
    expect(updated.id, 1);
    expect(updated.mileage, 100);
    expect(updated.type, ServiceType.oilChange);
  });

  test('copyWith without args is an equal-valued copy', () {
    final r = _record();
    final c = r.copyWith();
    expect(c.id, r.id);
    expect(c.date, r.date);
    expect(c.attachments, r.attachments);
  });
}

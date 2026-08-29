import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

void main() {
  const photo = VaultRef(
    path: 'v/1/car.jpg',
    contentType: 'image/jpeg',
    byteSize: 10,
  );
  const scan = VaultRef(
    path: 'v/1/registration.pdf',
    contentType: 'application/pdf',
    byteSize: 10,
  );

  test('reactivating keeps everything except isActive', () {
    // The management screen rebuilt the Automobile field by field to flip this
    // one flag, and the list had drifted: primaryImage, images, files and the
    // three registration fields were all missing, so reactivating a vehicle
    // erased its photo, its scans and its registration number.
    final auto = Automobile(
      id: 1,
      year: 2020,
      maker: 'Honda',
      model: 'Civic',
      plate: 'REG-1',
      meterReading: 100,
      isActive: false,
      registrationNumber: 'REG-NUMBER-1',
      registrationJurisdiction: 'Ontario',
      registrationIssuedDate: DateTime.utc(2026, 1, 1),
      registrationExpiryDate: DateTime.utc(2027, 1, 1),
      primaryImage: photo,
      images: const [photo],
      files: const [scan],
      notes: 'keep me',
    );

    final back = auto.copyWith(isActive: true);

    expect(back.isActive, isTrue);
    expect(back.primaryImage, photo);
    expect(back.images, [photo]);
    expect(back.files, [scan]);
    expect(back.registrationNumber, 'REG-NUMBER-1');
    expect(back.registrationJurisdiction, 'Ontario');
    expect(back.registrationIssuedDate, DateTime.utc(2026, 1, 1));
    expect(back.registrationExpiryDate, DateTime.utc(2027, 1, 1));
    expect(back.notes, 'keep me');
    expect(back.meterReading, 100);
  });
}

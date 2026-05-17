// End-to-end integration tests for local-tier attachments.
//
// Each layer (path util, codec, vault store, note repo, automobile
// repo, picker, resolver) has its own unit-test file. This one wires
// every real component together against an in-memory Drift database
// + a tmp-dir vault to make sure they cooperate the way the UI
// expects — and to lock in cross-layer behaviors (orphan files on
// Replace/Remove, two-car isolation, app-restart persistence,
// resolver fail-soft when bytes vanish behind its back) before
// Phase 11.5 starts rewiring the sync side.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_gas_log_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';

Automobile _seedAuto({
  int id = 0,
  int meter = 1,
  String plate = 'INT-001',
  AttachmentRef? primaryImage,
  List<AttachmentRef> images = const [],
}) =>
    Automobile(
      id: id,
      vin: '1HGBH41JXMN109186',
      maker: 'Honda',
      brand: 'Honda',
      model: 'Civic',
      year: 2020,
      plate: plate,
      engineType: 'Gasoline',
      fuelType: 'Regular',
      meterReading: meter,
      isActive: true,
      primaryImage: primaryImage,
      images: images,
    );

GasLog _gasLog({required int autoId, required double odometer}) => GasLog(
      id: 0,
      date: DateTime(2026, 5, 17, 10),
      automobileId: autoId,
      odometer: odometer,
      odometerUnit: 'Mile',
      distance: 100,
      distanceUnit: 'Mile',
      fuel: 5,
      fuelUnit: 'Gallon',
      fuelGrade: 'Regular',
      isFullTank: true,
      totalPrice: 20,
      unitPrice: 4,
      currency: 'CAD',
    );

Uint8List _bytes(String marker, {int size = 64}) {
  // Distinct payloads per test so we can assert bytes-equal between
  // what we wrote and what we read back. First byte = ASCII of marker.
  final list = List<int>.filled(size, marker.codeUnitAt(0));
  list[1] = size & 0xFF;
  return Uint8List.fromList(list);
}

void main() {
  late HmmDatabase db;
  late Directory tmpVault;
  late LocalVaultStore vaultStore;
  late LocalHmmNoteRepository noteRepo;
  late LocalNoteCatalogRepository catalogRepo;
  late LocalAutomobileRepository autoRepo;
  late LocalGasLogRepository gasLogRepo;
  late VaultImageAttachmentPicker picker;
  late VaultResolver resolver;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    tmpVault =
        await Directory.systemTemp.createTemp('hmm_attachments_int_');

    // Author + database wiring (mirrors what main.dart does at startup).
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'integration-tester'),
        );
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(aid)))
        .getSingle();

    noteRepo = LocalHmmNoteRepository(db, () async => author);
    catalogRepo = LocalNoteCatalogRepository(db);
    autoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
    gasLogRepo = LocalGasLogRepository(noteRepo, catalogRepo, autoRepo);
    vaultStore = LocalVaultStore(rootDir: tmpVault);
    picker = VaultImageAttachmentPicker(vaultStore: vaultStore);
    resolver = VaultResolver(vaultStore: vaultStore);
  });

  tearDown(() async {
    await db.close();
    if (await tmpVault.exists()) {
      await tmpVault.delete(recursive: true);
    }
  });

  group('full pick → save → retrieve → resolve flow', () {
    test('picker bytes survive intact through every layer', () async {
      final created = await autoRepo.createAutomobile(_seedAuto());
      final bytes = _bytes('A', size: 128);

      final ref = await picker.persistToVault(
        noteId: created.id,
        bytes: bytes,
        originalName: 'civic.jpg',
      );
      final saved = await autoRepo.getAutomobileById(created.id);
      final replaced = Automobile(
        id: saved.id,
        vin: saved.vin,
        maker: saved.maker,
        brand: saved.brand,
        model: saved.model,
        year: saved.year,
        plate: saved.plate,
        engineType: saved.engineType,
        fuelType: saved.fuelType,
        meterReading: saved.meterReading,
        isActive: true,
        primaryImage: ref,
      );
      await autoRepo.updateAutomobile(saved.id, replaced);

      // Pull from disk via the read path.
      final read = await autoRepo.getAutomobileById(created.id);
      expect(read.primaryImage, equals(ref));

      final resolvedBytes = await resolver.resolve(read.primaryImage!);
      expect(resolvedBytes, isNotNull);
      expect(resolvedBytes, equals(bytes),
          reason: 'resolver bytes must match picker input verbatim');
    });

    test('vault path follows the canonical layout', () async {
      final created = await autoRepo.createAutomobile(_seedAuto());
      final ref = await picker.persistToVault(
        noteId: created.id,
        bytes: _bytes('A'),
        originalName: 'shape.jpg',
      );

      expect(ref.path, startsWith('attachments/note-${created.id}/'));
      expect(ref.path, endsWith('.jpg'));
      expect(ref.contentType, equals('image/jpeg'));
    });

    test('a gallery of three photos all resolve', () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final refs = <VaultRef>[];
      final payloads = <Uint8List>[];
      for (final marker in ['A', 'B', 'C']) {
        final payload = _bytes(marker);
        payloads.add(payload);
        refs.add(await picker.persistToVault(
          noteId: car.id,
          bytes: payload,
          originalName: '$marker.png',
          contentTypeHint: 'image/png',
        ));
      }

      // Save with all three in `images`.
      final saved = Automobile(
        id: car.id,
        vin: car.vin,
        maker: car.maker,
        brand: car.brand,
        model: car.model,
        year: car.year,
        plate: car.plate,
        engineType: car.engineType,
        fuelType: car.fuelType,
        meterReading: car.meterReading,
        isActive: true,
        images: refs,
      );
      await autoRepo.updateAutomobile(car.id, saved);

      final read = await autoRepo.getAutomobileById(car.id);
      expect(read.images.length, equals(3));
      for (var i = 0; i < refs.length; i++) {
        final ref = read.images[i] as VaultRef;
        expect(ref.path, equals(refs[i].path));
        expect(await resolver.resolve(ref), equals(payloads[i]));
      }
    });
  });

  group('orphan-byte behavior (documented v1 limitation)', () {
    test('Replace leaves the old primary photo on disk', () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final firstRef = await picker.persistToVault(
        noteId: car.id,
        bytes: _bytes('A'),
        originalName: 'first.jpg',
      );
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
            primaryImage: firstRef,
          ));

      // Replace the photo.
      final secondRef = await picker.persistToVault(
        noteId: car.id,
        bytes: _bytes('B'),
        originalName: 'second.jpg',
      );
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
            primaryImage: secondRef,
          ));

      // First file still on disk (an orphan — a vault GC pass will
      // reclaim it later). Pointed-to file is the second.
      expect(await vaultStore.exists(firstRef.path), isTrue,
          reason: 'old primary should still exist on disk (orphan)');
      expect(await vaultStore.exists(secondRef.path), isTrue);

      final read = await autoRepo.getAutomobileById(car.id);
      expect(read.primaryImage, equals(secondRef));
    });

    test('Remove clears the column but leaves vault bytes on disk',
        () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final ref = await picker.persistToVault(
        noteId: car.id,
        bytes: _bytes('A'),
        originalName: 'pic.jpg',
      );
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
            primaryImage: ref,
          ));

      // Remove (primaryImage = null).
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
          ));

      final read = await autoRepo.getAutomobileById(car.id);
      expect(read.primaryImage, isNull);
      expect(await vaultStore.exists(ref.path), isTrue,
          reason: 'remove leaves an orphan; GC pass cleans it up later');
    });
  });

  group('isolation between cars', () {
    test('photo on car A is not visible on car B', () async {
      final carA = await autoRepo.createAutomobile(_seedAuto(plate: 'A'));
      final carB = await autoRepo.createAutomobile(_seedAuto(plate: 'B'));

      final refA = await picker.persistToVault(
        noteId: carA.id,
        bytes: _bytes('A'),
        originalName: 'a.jpg',
      );
      await autoRepo.updateAutomobile(
          carA.id,
          Automobile(
            id: carA.id,
            vin: carA.vin,
            maker: carA.maker,
            brand: carA.brand,
            model: carA.model,
            year: carA.year,
            plate: carA.plate,
            engineType: carA.engineType,
            fuelType: carA.fuelType,
            meterReading: carA.meterReading,
            isActive: true,
            primaryImage: refA,
          ));

      final readA = await autoRepo.getAutomobileById(carA.id);
      final readB = await autoRepo.getAutomobileById(carB.id);
      expect(readA.primaryImage, equals(refA));
      expect(readB.primaryImage, isNull);

      // Vault layout uses per-note folders.
      expect(refA.path, startsWith('attachments/note-${carA.id}/'));
      // The other car's folder shouldn't exist yet.
      final carBDir = Directory(
        '${tmpVault.path}${Platform.pathSeparator}attachments'
        '${Platform.pathSeparator}note-${carB.id}',
      );
      expect(await carBDir.exists(), isFalse);
    });
  });

  group('persistence across an "app restart"', () {
    test('photo is still attached after closing and reopening the db',
        () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final ref = await picker.persistToVault(
        noteId: car.id,
        bytes: _bytes('A'),
        originalName: 'persist.jpg',
      );
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
            primaryImage: ref,
          ));

      // The in-memory NativeDatabase resets on close, so simulate a
      // restart with a fresh repo against the SAME db handle (the
      // closest analogue we can run in-process without a file-backed
      // db). The vault directory persists across "restarts" because
      // it's on the same tmp dir.
      final freshAutoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
      final read = await freshAutoRepo.getAutomobileById(car.id);
      expect(read.primaryImage, equals(ref));

      // Resolver still finds the bytes.
      expect(await resolver.resolve(read.primaryImage!), isNotNull);
    });
  });

  group('resolver fail-soft when bytes vanish out-of-band', () {
    test('returns null after the file is deleted from disk', () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final ref = await picker.persistToVault(
        noteId: car.id,
        bytes: _bytes('A'),
        originalName: 'gone.jpg',
      );
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
            primaryImage: ref,
          ));

      // Simulate a user deleting the file behind the app's back
      // (Finder, terminal, OneDrive desync, etc).
      await vaultStore.delete(ref.path);

      final read = await autoRepo.getAutomobileById(car.id);
      // The column ref is still there...
      expect(read.primaryImage, equals(ref));
      // ...but the resolver returns null so the UI shows a placeholder.
      expect(await resolver.resolve(read.primaryImage!), isNull);
    });
  });

  group('cross-feature: gas log + photo', () {
    test('a gas log live-entry on a car with a photo preserves the photo',
        () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final ref = await picker.persistToVault(
        noteId: car.id,
        bytes: _bytes('A'),
        originalName: 'before-gas.jpg',
      );
      await autoRepo.updateAutomobile(
          car.id,
          Automobile(
            id: car.id,
            vin: car.vin,
            maker: car.maker,
            brand: car.brand,
            model: car.model,
            year: car.year,
            plate: car.plate,
            engineType: car.engineType,
            fuelType: car.fuelType,
            meterReading: car.meterReading,
            isActive: true,
            primaryImage: ref,
          ));

      // Live-entry gas log (should bump meter AND preserve photo).
      await gasLogRepo.createGasLog(
        car.id,
        _gasLog(autoId: car.id, odometer: 999),
      );

      final after = await autoRepo.getAutomobileById(car.id);
      expect(after.meterReading, equals(999));
      expect(after.primaryImage, equals(ref));
      // And the photo bytes are still readable.
      expect(await resolver.resolve(after.primaryImage!), isNotNull);
    });
  });

  group('vault list reflects the current note state', () {
    test('list under a note folder returns every persisted photo',
        () async {
      final car = await autoRepo.createAutomobile(_seedAuto());
      final refs = <VaultRef>[];
      for (final marker in ['A', 'B', 'C']) {
        refs.add(await picker.persistToVault(
          noteId: car.id,
          bytes: _bytes(marker),
          originalName: '$marker.jpg',
        ));
      }

      final listed = await vaultStore.list('attachments/note-${car.id}');
      expect(listed.length, equals(3));
      final listedPaths = listed.map((e) => e.relativePath).toSet();
      expect(listedPaths, equals(refs.map((r) => r.path).toSet()));
    });
  });
}

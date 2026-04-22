import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'database.g.dart';

class Authors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountName => text().withLength(min: 1, max: 256)();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();
  IntColumn get role => integer().withDefault(const Constant(0))();
  BoolColumn get isActivated => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [{accountName}];
}

class NoteCatalogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get schema => text()();
  TextColumn get render => text().nullable()();
  IntColumn get formatType => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{name}];
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subject => text().withLength(min: 1, max: 1000)();
  TextColumn get content => text().nullable()();
  IntColumn get authorId => integer().references(Authors, #id)();
  IntColumn get catalogId => integer().nullable().references(NoteCatalogs, #id)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BlobColumn get version => blob().nullable()();
  DateTimeColumn get createDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastModifiedDate => dateTime().nullable()();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();
  BoolColumn get isActivated => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [{name}];
}

class NoteTagRefs extends Table {
  IntColumn get noteId => integer().references(Notes, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

@DriftDatabase(tables: [Authors, NoteCatalogs, Notes, Tags, NoteTagRefs])
class HmmDatabase extends _$HmmDatabase {
  HmmDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('PRAGMA journal_mode=WAL');
    },
  );
}

const _dbPathKey = 'local_db_path';

Future<String> _resolveDbPath() async {
  final prefs = await SharedPreferences.getInstance();
  final customPath = prefs.getString(_dbPathKey);
  if (customPath != null && customPath.isNotEmpty) {
    final dir = Directory(p.dirname(customPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return customPath;
  }
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'hmm.db');
}

final hmmDatabaseProvider = Provider<HmmDatabase>((ref) {
  throw UnimplementedError(
    'hmmDatabaseProvider must be overridden at startup with the resolved database path',
  );
});

Future<HmmDatabase> createHmmDatabase() async {
  final dbPath = await _resolveDbPath();
  return HmmDatabase(NativeDatabase(File(dbPath)));
}

Future<void> setDatabasePath(String path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_dbPathKey, path);
}

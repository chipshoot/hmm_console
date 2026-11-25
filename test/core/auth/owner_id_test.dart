import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_author_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthors implements IAuthorRepository {
  _FakeAuthors(this.rows);
  final List<Author> rows;

  @override
  Future<List<Author>> getAuthors() async => rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Author _author(int id, String name) =>
    Author(id: id, accountName: name, role: 0, isActivated: true);

void main() {
  late OwnerIdStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OwnerIdStore(await SharedPreferences.getInstance());
  });

  Future<String> resolve({
    String? signedInSub,
    String? signedInEmail,
    String? peekSub,
    String? peekEmail,
    List<Author> rows = const [],
    Map<int, int> counts = const {},
  }) => resolveOwnerId(
    store: store,
    signedInSub: signedInSub,
    signedInEmail: signedInEmail,
    peekStoredSub: () async => peekSub,
    peekStoredEmail: () async => peekEmail,
    authors: _FakeAuthors(rows),
    noteCountsByAuthor: () async => counts,
    newId: () => 'NEW',
  );

  test('stored id wins over everything', () async {
    await store.setOwnerIdOnce('A');
    expect(await resolve(signedInSub: 'B', peekSub: 'C'), 'A');
  });

  test('signed-in sub is used and linked', () async {
    expect(await resolve(signedInSub: 'SUB', signedInEmail: 'a@b.c'), 'SUB');
    expect(store.ownerId, 'SUB');
    expect(store.linkedHmmSub, 'SUB');
    expect(store.linkedHmmEmail, 'a@b.c');
  });

  test('expired token sub used when signed out', () async {
    expect(await resolve(peekSub: 'OLD', peekEmail: 'o@b.c'), 'OLD');
    expect(store.ownerId, 'OLD');
    expect(store.linkedHmmSub, 'OLD');
    expect(store.linkedHmmEmail, 'o@b.c');
  });

  test('single author row', () async {
    expect(await resolve(rows: [_author(1, 'ROW')]), 'ROW');
    expect(store.linkedHmmSub, 'ROW');
  });

  test('several author rows picks the one with notes', () async {
    expect(
      await resolve(rows: [_author(1, 'X'), _author(2, 'Y')], counts: {2: 12}),
      'Y',
    );
  });

  test('several rows tie goes to the lowest id', () async {
    expect(await resolve(rows: [_author(3, 'Z'), _author(2, 'Y')]), 'Y');
  });

  test('fresh install gets a new id and no link', () async {
    expect(await resolve(), 'NEW');
    expect(store.ownerId, 'NEW');
    expect(store.linkedHmmSub, isNull);
  });

  test('setOwnerIdOnce twice throws StateError', () async {
    await store.setOwnerIdOnce('A');
    expect(() => store.setOwnerIdOnce('B'), throwsStateError);
  });

  test('adoptOwnerId overwrites', () async {
    await store.setOwnerIdOnce('A');
    await store.adoptOwnerId('B');
    expect(store.ownerId, 'B');
  });
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/states/contact_edit_state.dart';

import '../data/contact_repository_fakes.dart';

const _legacyZh =
    '{"schemaVersion":1,"displayName":"伟 张","id":"c-zh",'
    '"contactType":"person","firstName":"伟","lastName":"张",'
    '"phones":[],"emails":[],"addresses":[],'
    '"relationship":{"category":"family"},"isSelf":false,'
    '"isActivated":true}';

// Only the stored displayName is padded here; padded name parts are kept
// verbatim on an unedited save too (contact_edit_state_name_options_test).
const _paddedLatin =
    '{"schemaVersion":1,"displayName":"Ada  Lovelace ","id":"c-pad",'
    '"contactType":"person","firstName":"Ada","lastName":"Lovelace",'
    '"phones":[],"emails":[],"addresses":[],'
    '"relationship":{"category":"other"},"isSelf":false,'
    '"isActivated":true}';

void main() {
  for (final (label, json, id) in [
    ('Han', _legacyZh, 'c-zh'),
    ('padded Latin', _paddedLatin, 'c-pad'),
  ]) {
    test('opening and saving without edits keeps the stored bytes ($label)',
        () async {
      final initial = ContactCodec.fromMap(
        jsonDecode(json) as Map<String, dynamic>,
      );
      final repo = InMemoryContactRepository()..seed(initial);
      final c = ProviderContainer(
        overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(contactEditStateProvider(initial), (_, _) {});
      addTearDown(sub.close);

      expect(
        await c.read(contactEditStateProvider(initial).notifier).save(),
        isTrue,
      );
      final saved = (await repo.getContact(id))!;
      expect(jsonEncode(ContactCodec.toMap(saved)), json);
    });
  }

  test('saving after an edit writes the ordered displayName', () async {
    final initial = ContactCodec.fromMap(
      jsonDecode(_legacyZh) as Map<String, dynamic>,
    );
    final repo = InMemoryContactRepository()..seed(initial);
    final c = ProviderContainer(
      overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(contactEditStateProvider(initial), (_, _) {});
    addTearDown(sub.close);

    final n = c.read(contactEditStateProvider(initial).notifier);
    n.setNotes('met at school');
    expect(await n.save(), isTrue);
    final saved = (await repo.getContact('c-zh'))!;
    expect(ContactCodec.toMap(saved)['displayName'], '张伟');
  });
}

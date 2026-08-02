import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_launcher.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  group('uriForAction', () {
    test('call builds a tel: uri', () {
      expect(
        uriForAction(ValueAction.call, '(555) 123-4567').toString(),
        'tel:5551234567',
      );
    });

    test('map builds a maps uri', () {
      expect(
        uriForAction(ValueAction.map, '1 Main St').toString(),
        contains('maps.apple.com'),
      );
    });

    test('none has no uri', () {
      expect(uriForAction(ValueAction.none, 'anything'), isNull);
    });

    test('a blank value has no uri, whatever the action', () {
      expect(uriForAction(ValueAction.call, '   '), isNull);
      expect(uriForAction(ValueAction.map, ''), isNull);
    });
  });

  group('launchActionProvider', () {
    test('is overridable, so widgets never touch url_launcher in tests', () {
      final calls = <(ValueAction, String)>[];
      final container = ProviderContainer(
        overrides: [
          launchActionProvider.overrideWithValue(
            (action, value) async => calls.add((action, value)),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(launchActionProvider)(ValueAction.call, '5551234567');

      expect(calls, [(ValueAction.call, '5551234567')]);
    });
  });

  group('LaunchActionException', () {
    test('names the uri it could not open', () {
      final e = LaunchActionException(Uri.parse('tel:5551234567'));
      expect(e.toString(), contains('tel:5551234567'));
    });
  });
}

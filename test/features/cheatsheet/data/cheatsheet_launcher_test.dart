import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/launch_actions.dart';
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
    // It reaches logs; the uri carries a phone number or a street address.
    test('names only the scheme, never the number', () {
      final e = LaunchActionException(Uri.parse('tel:5551234'));
      expect(e.toString(), isNot(contains('5551234')));
      expect(e.toString(), contains('tel'));
    });

    test('names only the scheme, never the address', () {
      final e = LaunchActionException(mapsUri('1 Main St, Vancouver'));
      expect(e.toString(), isNot(contains('Main')));
      expect(e.toString(), isNot(contains('Vancouver')));
      expect(e.toString(), contains('https'));
    });
  });
}

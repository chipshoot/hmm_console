import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(double shortestSide) {
  final c = ProviderContainer(
    overrides: [deviceShortestSideProvider.overrideWithValue(shortestSide)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<bool> _settled(ProviderContainer c) async {
  c.read(remindOnDeviceProvider);
  await c.read(remindOnDeviceProvider.notifier).loaded;
  return c.read(remindOnDeviceProvider);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults on for a 390x844 phone', () async {
    expect(await _settled(_container(390)), isTrue);
  });

  test('defaults off for an 820x1180 tablet', () async {
    expect(await _settled(_container(820)), isFalse);
  });

  test('a stored value overrides the default', () async {
    SharedPreferences.setMockInitialValues({'calendar.remindOnDevice': false});
    expect(await _settled(_container(390)), isFalse);
    SharedPreferences.setMockInitialValues({'calendar.remindOnDevice': true});
    expect(await _settled(_container(820)), isTrue);
  });

  test('set persists under calendar.remindOnDevice', () async {
    final c = _container(390);
    await _settled(c);
    await c.read(remindOnDeviceProvider.notifier).set(false);
    expect(c.read(remindOnDeviceProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('calendar.remindOnDevice'), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';

void main() {
  group('SelectedAutomobileNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is null', () {
      expect(container.read(selectedAutomobileIdProvider), isNull);
    });

    test('select sets the automobile id', () {
      container.read(selectedAutomobileIdProvider.notifier).select(42);
      expect(container.read(selectedAutomobileIdProvider), 42);
    });

    test('select can be changed', () {
      container.read(selectedAutomobileIdProvider.notifier).select(42);
      container.read(selectedAutomobileIdProvider.notifier).select(99);
      expect(container.read(selectedAutomobileIdProvider), 99);
    });

    test('select to null clears selection', () {
      container.read(selectedAutomobileIdProvider.notifier).select(42);
      container.read(selectedAutomobileIdProvider.notifier).select(null);
      expect(container.read(selectedAutomobileIdProvider), isNull);
    });
  });
}

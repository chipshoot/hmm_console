import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/automobile_records/data/repositories/service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/service_record_form_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/service_line_item_row.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_service_record_state.dart';

/// Returns the record via a SynchronousFuture so `_loadExisting` completes
/// without a loading-spinner frame in between — the exact fast-load timing
/// that hid the loaded line items when the editor's key wasn't bumped.
class _SyncRepo implements IServiceRecordRepository {
  _SyncRepo(this.record);
  final ServiceRecord record;

  @override
  Future<ServiceRecord> getRecordById(int autoId, int id) =>
      SynchronousFuture(record);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

void main() {
  testWidgets('edit form shows the saved line items on open (fast load)',
      (tester) async {
    final record = ServiceRecord(
      id: 1,
      automobileId: 7,
      date: DateTime(2026),
      mileage: 50,
      type: ServiceType.oilChange,
      parts: const [
        PartItem(
            type: LineItemType.part,
            name: 'Oil filter',
            quantity: 1,
            unitCost: 12.0,
            currency: 'CAD'),
      ],
    );

    final container = ProviderContainer(overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(_SyncRepo(record)),
      // cloudApi so the attachments section (which needs a vault resolver) is
      // skipped; the repo is overridden directly regardless of mode.
      dataModeProvider.overrideWith(() => _StubMode(DataMode.cloudApi)),
    ]);
    addTearDown(container.dispose);
    // Settle the mutate provider to AsyncData up front so the form's
    // "record saved -> pop" listener doesn't fire on a loading->data
    // transition when it first watches the provider.
    await container.read(mutateServiceRecordStateProvider.future);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) =>
              const ServiceRecordFormScreen(automobileId: 7, recordId: 1),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The line-items editor must render the loaded part, not an empty list.
    expect(find.byType(ServiceLineItemRow), findsOneWidget);
    expect(find.text('Oil filter'), findsOneWidget);
  });
}

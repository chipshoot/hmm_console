import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/data/data_mode.dart';
import '../../../../core/data/sync/onedrive_auth.dart';
import '../../../../core/data/sync/onedrive_config.dart';
import '../../../../core/data/sync/sync_orchestrator.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../domain/gas_log_units.dart';
import '../../providers/gas_log_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickDatabaseFolder(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose database folder',
    );
    if (result == null) return;

    final newPath = p.join(result, 'hmm.db');
    await updateDatabasePath(newPath);
    ref.invalidate(databasePathProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database location set to $result. Restart app to apply.'),
        ),
      );
    }
  }

  Future<void> _resetToDefault(BuildContext context, WidgetRef ref) async {
    await updateDatabasePath('');
    ref.invalidate(databasePathProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to default location. Restart app to apply.')),
      );
    }
  }

  Future<void> _signInOneDrive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(oneDriveAuthProvider).signIn();
      ref.invalidate(oneDriveAuthStateProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Signed in to OneDrive')),
      );
    } on OneDriveAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _signOutOneDrive(BuildContext context, WidgetRef ref) async {
    await ref.read(oneDriveAuthProvider).signOut();
    ref.invalidate(oneDriveAuthStateProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out of OneDrive')),
      );
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final orchestrator = ref.read(syncOrchestratorProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Syncing…')));
    final result = await orchestrator.syncNow();
    messenger.clearSnackBars();
    if (result.success) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Synced — pushed ${result.pushedNotes} / pulled ${result.pulledNotes} notes',
        ),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text('Sync failed: ${result.errors.first.message}'),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gasLogSettingsProvider);
    final dataMode = ref.watch(dataModeProvider);
    final cloudProvider = ref.watch(cloudProviderProvider);
    final dbPathAsync = ref.watch(databasePathProvider);

    return CommonScreenScaffold(
      title: 'Settings',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Data Storage',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            GapWidgets.h16,
            DropdownButtonFormField<DataMode>(
              initialValue: dataMode,
              decoration: const InputDecoration(
                labelText: 'Storage Mode',
                border: OutlineInputBorder(),
              ),
              items: DataMode.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(dataModeProvider.notifier).setMode(v);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${v.displayName}. Restart app to apply.'),
                    ),
                  );
                }
              },
            ),
            GapWidgets.h8,
            Text(
              dataMode.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (dataMode == DataMode.cloudStorage) ...[
              GapWidgets.h16,
              DropdownButtonFormField<CloudProvider>(
                initialValue: cloudProvider,
                decoration: const InputDecoration(
                  labelText: 'Cloud Provider',
                  border: OutlineInputBorder(),
                ),
                items: CloudProvider.values
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(cloudProviderProvider.notifier).setProvider(v);
                  }
                },
              ),
              GapWidgets.h8,
              if (!OneDriveConfig.isConfigured)
                Text(
                  'OneDrive client ID not set. Rebuild with --dart-define=ONEDRIVE_CLIENT_ID=<app-id> (see docs/cloud_storage_setup.md §1).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                )
              else
                ref.watch(oneDriveAuthStateProvider).when(
                      data: (signedIn) => signedIn
                          ? OutlinedButton.icon(
                              onPressed: () => _signOutOneDrive(context, ref),
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign out of OneDrive'),
                            )
                          : FilledButton.icon(
                              onPressed: () => _signInOneDrive(context, ref),
                              icon: const Icon(Icons.cloud_outlined),
                              label: const Text('Sign in to OneDrive'),
                            ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Auth state error: $e'),
                    ),
            ],
            if (dataMode != DataMode.local) ...[
              GapWidgets.h16,
              FilledButton.icon(
                onPressed: () => _syncNow(context, ref),
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
            ],
            if (dataMode == DataMode.local) ...[
              GapWidgets.h16,
              dbPathAsync.when(
                data: (path) => InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Database Location',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          path,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              GapWidgets.h8,
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDatabaseFolder(context, ref),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Change Location'),
                  ),
                  GapWidgets.w8,
                  TextButton(
                    onPressed: () => _resetToDefault(context, ref),
                    child: const Text('Reset to Default'),
                  ),
                ],
              ),
            ],
            GapWidgets.h24,
            const Divider(),
            GapWidgets.h24,
            Text(
              'Gas Log Defaults',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            GapWidgets.h16,
            DropdownButtonFormField<DistanceUnit>(
              initialValue: settings.distanceUnit,
              decoration: const InputDecoration(
                labelText: 'Distance Unit',
                border: OutlineInputBorder(),
              ),
              items: DistanceUnit.values
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(gasLogSettingsProvider.notifier)
                      .update(distanceUnit: v);
                }
              },
            ),
            GapWidgets.h16,
            DropdownButtonFormField<FuelUnit>(
              initialValue: settings.fuelUnit,
              decoration: const InputDecoration(
                labelText: 'Fuel Unit',
                border: OutlineInputBorder(),
              ),
              items: FuelUnit.values
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(gasLogSettingsProvider.notifier)
                      .update(fuelUnit: v);
                }
              },
            ),
            GapWidgets.h16,
            DropdownButtonFormField<CurrencyCode>(
              initialValue: settings.currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: CurrencyCode.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(gasLogSettingsProvider.notifier)
                      .update(currency: v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

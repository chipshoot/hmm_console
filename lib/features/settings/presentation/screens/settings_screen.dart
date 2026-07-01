import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/navigation/route_names.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/data_mode.dart';
import '../../../../core/data/local/database.dart';
import '../../../../core/data/vault/vault_gc.dart';
import '../../../../core/data/sync/onedrive_auth.dart';
import '../../../../core/data/sync/onedrive_config.dart';
import '../../../../core/data/sync/sync_controller.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../receipt_scan/presentation/receipt_extraction_settings_section.dart';
import '../../../../core/widgets/gaps.dart';
import '../widgets/sync_status_card.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../domain/gas_log_units.dart';
import '../../domain/sync_settings.dart';
import '../../providers/gas_log_settings_provider.dart';
import '../../providers/geo_capture_provider.dart';
import '../../providers/sync_settings_provider.dart';

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

  Future<void> _pickVaultFolder(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose vault folder (e.g. inside your OneDrive)',
    );
    if (result == null) return;

    await setCloudStorageVaultPath(result);
    ref.invalidate(cloudStorageVaultPathProvider);
    // The vault root + every downstream provider (store, resolver,
    // picker) reads from this; invalidate so they pick up the change.
    ref.invalidate(vaultRootDirectoryProvider);
    ref.invalidate(vaultStoreProvider);
    ref.invalidate(attachmentResolverProvider);
    ref.invalidate(imageAttachmentPickerProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vault folder set to $result/vault. New photos will land there.',
          ),
        ),
      );
    }
  }

  Future<void> _resetVaultFolder(BuildContext context, WidgetRef ref) async {
    await setCloudStorageVaultPath(null);
    ref.invalidate(cloudStorageVaultPathProvider);
    ref.invalidate(vaultRootDirectoryProvider);
    ref.invalidate(vaultStoreProvider);
    ref.invalidate(attachmentResolverProvider);
    ref.invalidate(imageAttachmentPickerProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vault folder reset to default (app docs). '
            'cloudStorage byte sync will not work until you choose a folder.',
          ),
        ),
      );
    }
  }

  /// Reclaim vault bytes no note references any more (orphans left by
  /// cancel-after-pick / replace / remove). Filesystem tiers only —
  /// the entry point is hidden in cloudApi mode. Previews the count
  /// with a dry-run, confirms, then deletes.
  Future<void> _cleanUpVault(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = await ref.read(vaultStoreProvider.future);
      final db = ref.read(hmmDatabaseProvider);
      final gc = VaultGarbageCollector(store);
      final referenced = await collectReferencedVaultPaths(db);
      final preview = await gc.sweep(referenced, dryRun: true);

      if (preview.isClean) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No unused photo files to clean up.')),
        );
        return;
      }

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clean up unused photos?'),
          content: Text(
            'Found ${preview.deletedCount} unused file'
            '${preview.deletedCount == 1 ? '' : 's'} '
            '(${_formatBytes(preview.bytesReclaimed)}) left behind by '
            'cancelled or replaced photo picks. These are not referenced '
            'by any vehicle and can be safely deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Re-collect in case anything changed while the dialog was open,
      // then delete for real.
      final fresh = await collectReferencedVaultPaths(db);
      final result = await gc.sweep(fresh);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Reclaimed ${result.deletedCount} file'
            '${result.deletedCount == 1 ? '' : 's'} '
            '(${_formatBytes(result.bytesReclaimed)}).',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Clean-up failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    } catch (e) {
      // Catch-all so an unexpected error type (e.g., raw PlatformException
      // from the appauth bridge) still surfaces in the UI instead of
      // disappearing silently.
      messenger.showSnackBar(
        SnackBar(
          content: Text('OneDrive sign-in failed: $e'),
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
    // Route through SyncController (not SyncOrchestrator) so status
    // updates fan out to SyncStatusCard via its ChangeNotifier. Also
    // gate on the WiFi-only confirm dialog (decision C1) before
    // bypassing — same helper the embedded card button uses.
    final proceed = await confirmManualSyncIfOnCellular(context, ref);
    if (!proceed) return;
    if (!context.mounted) return;

    final controller = ref.read(syncControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Syncing…')));
    final result = await controller.triggerManualSync();
    messenger.clearSnackBars();
    if (result == null) {
      // In-flight — the card's spinner is already showing.
      return;
    }
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
    final selectedLocale = ref.watch(localeProvider);
    final l = AppLocalizations.of(context);

    return CommonScreenScaffold(
      title: l.settingsTitle,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apps),
              title: const Text('Launcher'),
              subtitle: const Text('Pin favorites and set search aliases'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(RouterNames.launcherManage.name),
            ),
            const Divider(),
            GapWidgets.h8,
            DropdownButtonFormField<String?>(
              initialValue: selectedLocale?.languageCode,
              decoration: InputDecoration(
                labelText: l.settingsLanguage,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l.settingsLanguageFollowSystem),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l.settingsLanguageEnglish),
                ),
                DropdownMenuItem(
                  value: 'zh',
                  child: Text(l.settingsLanguageChinese),
                ),
              ],
              onChanged: (code) {
                ref.read(localeProvider.notifier).setLocale(
                      code == null ? null : Locale(code),
                    );
              },
            ),
            GapWidgets.h24,
            const Divider(),
            GapWidgets.h8,
            Builder(builder: (context) {
              final geo = ref.watch(geoCaptureEnabledProvider);
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add location to new notes'),
                subtitle: const Text(
                    'Capture your location when you create a note'),
                value: geo.asData?.value ?? false,
                onChanged: geo.isLoading
                    ? null
                    : (v) => ref
                        .read(geoCaptureEnabledProvider.notifier)
                        .setEnabled(v),
              );
            }),
            GapWidgets.h8,
            const Divider(),
            GapWidgets.h24,
            const ReceiptExtractionSettingsSection(),
            GapWidgets.h24,
            const Divider(),
            GapWidgets.h24,
            Text(
              l.settingsDataStorage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            GapWidgets.h16,
            DropdownButtonFormField<DataMode>(
              initialValue: dataMode,
              decoration: InputDecoration(
                labelText: l.settingsStorageMode,
                border: const OutlineInputBorder(),
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
                decoration: InputDecoration(
                  labelText: l.settingsCloudProvider,
                  border: const OutlineInputBorder(),
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
              GapWidgets.h16,
              // Vault folder picker. Photos / attachment bytes land
              // here; pointing this inside the user's OneDrive folder
              // is what makes multi-device sync work (the OS-level
              // OneDrive client moves the files). Hidden on iOS, which
              // doesn't surface a desktop-style OneDrive folder; iOS
              // cloudStorage falls back to the app's docs directory.
              if (!Platform.isIOS) ...[
                _VaultFolderRow(
                  onPick: () => _pickVaultFolder(context, ref),
                  onReset: () => _resetVaultFolder(context, ref),
                ),
                GapWidgets.h16,
              ],
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
                              label: Text(l.settingsSignOutOneDrive),
                            )
                          : FilledButton.icon(
                              onPressed: () => _signInOneDrive(context, ref),
                              icon: const Icon(Icons.cloud_outlined),
                              label: Text(l.settingsSignInOneDrive),
                            ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Auth state error: $e'),
                    ),
            ],
            if (dataMode != DataMode.local) ...[
              GapWidgets.h16,
              // SyncStatusCard renders the live status line + an
              // embedded "Sync now" button wired to SyncController, so
              // the in-flight state is shared with auto-sync. The
              // standalone FilledButton below is kept as a fallback
              // entry point for accessibility / legacy flows.
              const SyncStatusCard(),
              GapWidgets.h8,
              // WiFi-only vs Any network toggle (Phase C). Auto-sync
              // respects this; manual "Sync now" bypasses with a
              // confirm dialog (decision C1). Default is WiFi only
              // (decision C2). Hidden when DataMode == local because
              // there's nothing to sync.
              _SyncNetworkPolicySection(),
              GapWidgets.h8,
              FilledButton.icon(
                onPressed: () => _syncNow(context, ref),
                icon: const Icon(Icons.sync),
                label: Text(l.settingsSyncNow),
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
            // Vault maintenance — reclaim photo bytes orphaned by
            // cancelled / replaced picks. Filesystem tiers only; in
            // cloudApi mode the bytes live server-side and there's no
            // local vault to sweep.
            if (dataMode != DataMode.cloudApi) ...[
              GapWidgets.h16,
              OutlinedButton.icon(
                onPressed: () => _cleanUpVault(context, ref),
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('Clean up unused photos'),
              ),
            ],
            GapWidgets.h24,
            const Divider(),
            GapWidgets.h24,
            Text(
              'Vehicle Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            GapWidgets.h8,
            SwitchListTile(
              title: const Text('Show Registration card'),
              subtitle: const Text(
                'Turn off if your jurisdiction no longer requires '
                'periodic vehicle-registration renewal (e.g. Ontario '
                'retired the renewal sticker in 2022).',
              ),
              isThreeLine: true,
              contentPadding: EdgeInsets.zero,
              value: settings.showRegistration,
              onChanged: (v) {
                ref
                    .read(gasLogSettingsProvider.notifier)
                    .update(showRegistration: v);
              },
            ),
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

/// Vault folder UI for cloudStorage tier: shows the current path and
/// the pick / reset actions. Pulled out so SettingsScreen's build
/// stays readable; the Consumer here is so the row reactively
/// rebuilds when the path changes.
class _VaultFolderRow extends ConsumerWidget {
  const _VaultFolderRow({required this.onPick, required this.onReset});

  final VoidCallback onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(cloudStorageVaultPathProvider);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pathAsync.when(
          data: (path) => InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Vault folder (for photos)',
              border: OutlineInputBorder(),
              helperText:
                  'Point this inside your OneDrive folder so vehicle '
                  'photos sync across devices automatically.',
              helperMaxLines: 3,
            ),
            child: Text(
              path == null || path.isEmpty
                  ? 'Default (app sandbox — no cross-device sync)'
                  : '$path/vault',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle:
                        path == null ? FontStyle.italic : FontStyle.normal,
                    color: path == null ? cs.onSurfaceVariant : null,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Vault path error: $e'),
        ),
        GapWidgets.h8,
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose Folder'),
            ),
            GapWidgets.w8,
            pathAsync.when(
              data: (path) => path == null || path.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: onReset,
                      child: const Text('Reset to Default'),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Radio group letting the user pick between "WiFi only" (default) and
/// "Any network" for auto-sync. Decisions C1 + C2 in `task_plan.md`.
/// Manual taps on "Sync now" bypass this with a confirm dialog handled
/// by `confirmManualSyncIfOnCellular` in `sync_status_card.dart`.
class _SyncNetworkPolicySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyNotifier = ref.watch(syncSettingsProvider.notifier);
    final current = ref.watch(syncSettingsProvider).networkPolicy;
    final theme = Theme.of(context);

    // RadioGroup<T> is the post-Flutter-3.32 ancestor that owns the
    // shared selection — gets us off the deprecated per-tile
    // `groupValue` / `onChanged` API in one move.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
          child: Text(
            'Sync over',
            style: theme.textTheme.titleSmall,
          ),
        ),
        RadioGroup<SyncNetworkPolicy>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) policyNotifier.setNetworkPolicy(v);
          },
          child: const Column(
            children: [
              RadioListTile<SyncNetworkPolicy>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: SyncNetworkPolicy.wifiOnly,
                title: Text('WiFi only'),
                subtitle: Text(
                  'Auto-sync waits for WiFi. Manual "Sync now" asks first '
                  "when you're on cellular.",
                ),
              ),
              RadioListTile<SyncNetworkPolicy>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: SyncNetworkPolicy.anyNetwork,
                title: Text('Any network'),
                subtitle: Text(
                  'Auto-sync may use cellular data. You pay for any overage.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

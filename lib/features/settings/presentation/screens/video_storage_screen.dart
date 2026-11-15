import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/video/video_cache.dart';
import '../../../../core/data/sync/video_upload_scheduler.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../core/util/format_bytes.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Null when there is no on-disk vault (nothing to show).
final _videoUsageProvider = FutureProvider.autoDispose<VideoCacheUsage?>((
  ref,
) async {
  final cache = await ref.watch(videoCacheProvider.future);
  return cache?.usage();
});

/// Settings -> Videos: what downloaded videos use on this device, the
/// "Upload on mobile data" switch, and Clear downloaded videos.
class VideoStorageScreen extends ConsumerWidget {
  const VideoStorageScreen({super.key});

  Future<void> _setMobileData(WidgetRef ref, bool v) async {
    await ref.read(settingsProvider.notifier).setVideoUploadOnMobileData(v);
    try {
      await ref.read(videoUploadSchedulerProvider).maybeRun();
    } catch (e) {
      debugPrint('Video upload kick failed: ${e.runtimeType}');
    }
  }

  Future<bool> _confirmClear(
    BuildContext context,
    AppLocalizations l,
    int bytes,
  ) async {
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final body = Text(l.videoStorageClearConfirm(formatVideoSize(bytes)));
    final bool? ok;
    if (apple) {
      ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: body,
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.videoStorageClear),
            ),
          ],
        ),
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: body,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.videoStorageClear),
            ),
          ],
        ),
      );
    }
    return ok ?? false;
  }

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref,
    int downloadedBytes,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirmClear(context, l, downloadedBytes)) return;
    final cache = await ref.read(videoCacheProvider.future);
    if (cache == null) return;
    final freed = await cache.clearDownloaded();
    ref.invalidate(_videoUsageProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l.videoStorageCleared(formatVideoSize(freed)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final usage = ref.watch(_videoUsageProvider).value;
    final onMobile = ref.watch(
      settingsProvider.select((s) => s.value?.videoUploadOnMobileData ?? false),
    );
    return AppScaffold(
      title: l.videoStorageTitle,
      actions: const [HelpButton(helpId: HelpId.videoStorage)],
      slivers: [
        SliverList.list(
          children: [
            ListTile(
              leading: const Icon(Icons.download_done_outlined),
              title: Text(l.videoStorageDownloaded),
              subtitle: usage == null
                  ? null
                  : Text(
                      l.settingsVideosUsage(
                        formatVideoSize(usage.downloadedBytes),
                        formatVideoSize(kVideoCacheLimitBytes),
                      ),
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.offline_pin_outlined),
              title: Text(l.videoStorageKeptOffline),
              subtitle: usage == null
                  ? null
                  : Text(
                      l.videoStorageKeptSummary(
                        usage.keptCount,
                        formatVideoSize(usage.keptBytes),
                      ),
                    ),
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.cell_tower),
              title: Text(l.videoStorageMobileData),
              subtitle: Text(l.videoStorageMobileDataHint),
              value: onMobile,
              onChanged: (v) => _setMobileData(ref, v),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l.videoStorageClear),
              enabled: usage != null,
              onTap: usage == null
                  ? null
                  : () => _clear(context, ref, usage.downloadedBytes),
            ),
          ],
        ),
      ],
    );
  }
}

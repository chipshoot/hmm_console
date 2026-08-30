import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/driver_licence.dart';
import '../../states/driver_licence_state.dart';
import 'licence_show_screen.dart';

/// Edit the licence details and capture a photo of each side.
///
/// One screen for both "add" and "edit": there is only ever one licence, so a
/// separate create flow would be a second path to the same state.
class DriverLicenceScreen extends ConsumerStatefulWidget {
  const DriverLicenceScreen({super.key});

  @override
  ConsumerState<DriverLicenceScreen> createState() =>
      _DriverLicenceScreenState();
}

class _DriverLicenceScreenState extends ConsumerState<DriverLicenceScreen> {
  final _number = TextEditingController();
  final _licenceClass = TextEditingController();
  final _jurisdiction = TextEditingController();
  DateTime? _issued;
  DateTime? _expiry;

  /// Picks held until save, so leaving the screen writes nothing to the vault.
  PickedImageBytes? _newFront;
  PickedImageBytes? _newBack;

  /// Set once from the loaded licence. Without this the controllers would be
  /// rewritten on every rebuild and clear the caret mid-edit.
  bool _seeded = false;

  @override
  void dispose() {
    _number.dispose();
    _licenceClass.dispose();
    _jurisdiction.dispose();
    super.dispose();
  }

  void _seed(DriverLicence? l) {
    if (_seeded || l == null) return;
    _seeded = true;
    _number.text = l.number ?? '';
    _licenceClass.text = l.licenceClass ?? '';
    _jurisdiction.text = l.jurisdiction ?? '';
    _issued = l.issuedDate;
    _expiry = l.expiryDate;
  }

  String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _pick({required bool front}) async {
    final pick = await ref
        .read(imageByteSourceProvider)
        .pick(AttachmentPickSource.camera);
    // The camera is an OS sheet; the user can leave the screen while it is up.
    if (pick == null || !mounted) return;
    setState(() {
      if (front) {
        _newFront = pick;
      } else {
        _newBack = pick;
      }
    });
  }

  Future<void> _save(DriverLicence? current) async {
    await ref.read(driverLicenceStateProvider.notifier).save(
          DriverLicence(
            number: _orNull(_number.text),
            licenceClass: _orNull(_licenceClass.text),
            jurisdiction: _orNull(_jurisdiction.text),
            issuedDate: _issued,
            expiryDate: _expiry,
            // Carried across so a details-only save does not drop the photos.
            frontImage: current?.frontImage,
            backImage: current?.backImage,
            extraFields: current?.extraFields ?? const {},
          ),
          newFront: _newFront,
          newBack: _newBack,
        );
    if (!mounted) return;
    setState(() {
      _newFront = null;
      _newBack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(driverLicenceStateProvider);
    final licence = async.value;
    _seed(licence);

    // A failed save used to look EXACTLY like a successful one: the error left
    // `value` null, so the screen reported "No licence saved yet" — which is a
    // lie, and sends the user off to re-enter data that was never rejected out
    // loud. Surface it instead.
    ref.listen<AsyncValue<DriverLicence?>>(driverLicenceStateProvider,
        (_, next) {
      if (!next.hasError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    });

    return CommonScreenScaffold(
      title: l.licenceTitle,
      actions: [
        if (licence != null && licence.hasImages)
          IconButton(
            key: const Key('showLicenceAction'),
            icon: const Icon(Icons.badge_outlined),
            tooltip: l.licenceShow,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LicenceShowScreen(licence: licence),
              ),
            ),
          ),
      ],
      child: ListView(
        children: [
          // Three different states, and only ONE of them means "you have no
          // licence". Collapsing them is how a licence that exists reports
          // itself missing: on the first frame the read has not returned, so
          // `value` is null, and the screen used to announce "No licence saved
          // yet" over a licence that was there all along.
          if (async.isLoading && !async.hasValue)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(
                child: SizedBox(
                  key: Key('licenceLoading'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            )
          else if (async.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                async.error.toString(),
                key: const Key('licenceErrorLabel'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else if (licence == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l.licenceEmpty,
                  key: const Key('licenceEmptyLabel'),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          AppTextFormField(
            key: const Key('licenceNumberField'),
            fieldController: _number,
            fieldValidator: (_) => null,
            label: l.licenceNumber,
          ),
          GapWidgets.h16,
          AppTextFormField(
            key: const Key('licenceClassField'),
            fieldController: _licenceClass,
            fieldValidator: (_) => null,
            label: l.licenceClass,
          ),
          GapWidgets.h16,
          AppTextFormField(
            key: const Key('licenceJurisdictionField'),
            fieldController: _jurisdiction,
            fieldValidator: (_) => null,
            label: l.licenceJurisdiction,
          ),
          GapWidgets.h16,
          _dateRow(l.licenceIssued, _issued, const Key('licenceIssuedField'),
              (d) => setState(() => _issued = d)),
          _dateRow(l.licenceExpires, _expiry, const Key('licenceExpiryField'),
              (d) => setState(() => _expiry = d)),
          GapWidgets.h24,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _imageSlot(
                  label: l.licenceFront,
                  capture: l.licenceCaptureFront,
                  saved: licence?.frontImage,
                  pending: _newFront,
                  slotKey: 'licenceFrontSlot',
                  onCapture: () => _pick(front: true),
                ),
              ),
              GapWidgets.w12,
              Expanded(
                child: _imageSlot(
                  label: l.licenceBack,
                  capture: l.licenceCaptureBack,
                  saved: licence?.backImage,
                  pending: _newBack,
                  slotKey: 'licenceBackSlot',
                  onCapture: () => _pick(front: false),
                ),
              ),
            ],
          ),
          GapWidgets.h24,
          FilledButton(
            key: const Key('licenceSaveButton'),
            onPressed: async.isLoading ? null : () => _save(licence),
            child: Text(licence == null ? l.licenceAdd : l.licenceEdit),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(
    String label,
    DateTime? value,
    Key key,
    ValueChanged<DateTime?> onChanged,
  ) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null
          ? l.vehicleValueNotSet
          : '${value.year}-${value.month.toString().padLeft(2, '0')}-'
              '${value.day.toString().padLeft(2, '0')}'),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }

  Widget _imageSlot({
    required String label,
    required String capture,
    required VaultRef? saved,
    required PickedImageBytes? pending,
    required String slotKey,
    required VoidCallback onCapture,
  }) {
    final cs = Theme.of(context).colorScheme;
    final resolver = ref.watch(attachmentResolverProvider).value;

    Widget body;
    if (pending != null) {
      // Shown straight from memory: the bytes are not in the vault until save.
      body = Image.memory(pending.bytes, fit: BoxFit.cover);
    } else if (saved != null) {
      // The resolver arrives asynchronously (the vault may need unlocking).
      // Until it does this stays a neutral placeholder and NOT the capture
      // prompt — prompting to capture over a photo that already exists reads
      // as "there is nothing here", and the obvious response is to overwrite
      // it.
      body = resolver == null
          ? Container(
              key: const Key('licenceImageLoading'),
              color: cs.surfaceContainerHighest)
          : AttachmentImage(
              ref: saved,
              resolver: resolver,
              loadingPlaceholder: Container(color: cs.surfaceContainerHighest),
              errorPlaceholder: Container(color: cs.surfaceContainerHighest),
            );
    } else {
      body = Center(
        child: Text(capture,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        GapWidgets.h4,
        InkWell(
          key: Key(slotKey),
          onTap: onCapture,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: body,
          ),
        ),
      ],
    );
  }
}

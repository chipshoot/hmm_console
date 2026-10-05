import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/util/calling_codes.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// What the picker returned. A null [code] means "no country code"; a null
/// [CallingCodeChoice] from the opener means the sheet was dismissed.
class CallingCodeChoice {
  const CallingCodeChoice(this.code);
  final CallingCode? code;
}

/// Opens the searchable calling-code picker: a Cupertino popup on iOS, a
/// Material bottom sheet elsewhere.
Future<CallingCodeChoice?> showCallingCodePicker(
  BuildContext context, {
  CallingCode? selected,
}) {
  final sheet = _CallingCodeSheet(selected: selected);
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<CallingCodeChoice>(
      context: context,
      builder: (_) => CupertinoPopupSurface(child: sheet),
    );
  }
  return showModalBottomSheet<CallingCodeChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => sheet,
  );
}

class _CallingCodeSheet extends StatefulWidget {
  const _CallingCodeSheet({this.selected});
  final CallingCode? selected;

  @override
  State<_CallingCodeSheet> createState() => _CallingCodeSheetState();
}

class _CallingCodeSheetState extends State<_CallingCodeSheet> {
  List<CallingCode> _hits = callingCodes;

  void _search(String q) => setState(() => _hits = searchCallingCodes(q));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final theme = Theme.of(context);
    final showNone = _hits.length == callingCodes.length;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l.contactCountryCodeTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: isIos
                      ? CupertinoSearchTextField(
                          key: const Key('calling-code-search'),
                          placeholder: l.contactCountryCodeSearchHint,
                          onChanged: _search,
                        )
                      : TextField(
                          key: const Key('calling-code-search'),
                          autofocus: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: l.contactCountryCodeSearchHint,
                          ),
                          onChanged: _search,
                        ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _hits.length + (showNone ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showNone && i == 0) {
                        return _Row(
                          key: const Key('calling-code-none'),
                          flag: '',
                          name: l.contactCountryCodeNone,
                          code: '',
                          selected: widget.selected == null,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(const CallingCodeChoice(null)),
                        );
                      }
                      final c = _hits[i - (showNone ? 1 : 0)];
                      return _Row(
                        key: Key('calling-code-${c.iso}'),
                        flag: flagEmoji(c.iso),
                        name: c.name,
                        code: '+${c.code}',
                        selected: widget.selected == c,
                        onTap: () =>
                            Navigator.of(context).pop(CallingCodeChoice(c)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.flag,
    required this.name,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String name;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text(flag)),
            Expanded(
              child: Text(
                name,
                style: selected
                    ? theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.bodyLarge,
              ),
            ),
            Text(code, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Keeps digits, spaces, `-`, `(`, `)`, `.` and a `+` at the very start.
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final b = StringBuffer();
    for (var i = 0; i < newValue.text.length; i++) {
      final ch = newValue.text[i];
      if (RegExp(r'[0-9 \-().]').hasMatch(ch) || (ch == '+' && b.isEmpty)) {
        b.write(ch);
      }
    }
    final out = b.toString();
    if (out == newValue.text) return newValue;
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, out.length),
      ),
    );
  }
}

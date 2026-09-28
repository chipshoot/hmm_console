import 'package:flutter/widgets.dart';

/// One explained control. [icon] is the same constant the real control uses,
/// so the sheet shows what the user sees on screen.
class HelpEntry {
  const HelpEntry({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

/// A screen's help, built from localized strings.
class ScreenHelp {
  const ScreenHelp(
      {required this.title, required this.summary, required this.entries});
  final String title;
  final String summary;
  final List<HelpEntry> entries;
}

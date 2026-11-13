import 'package:flutter/material.dart';

import '../l10n/app_locale_controller.dart';
import '../l10n/app_translations.dart';

/// Selectable-text counterpart to AppText. Unknown resident-entered strings,
/// UPI IDs and references remain unchanged because the phrasebook is offline.
class AppSelectableText extends StatelessWidget {
  const AppSelectableText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.translate = false,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final bool translate;

  @override
  Widget build(BuildContext context) {
    final activeLocale = AppLocaleScope.watch(context);
    return SelectableText(
      translate ? AppTranslations.translate(data, activeLocale) : data,
      style: style,
      maxLines: maxLines,
    );
  }
}

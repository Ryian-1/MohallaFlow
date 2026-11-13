import 'package:flutter/material.dart';

import '../l10n/app_locale_controller.dart';
import '../theme/app_theme.dart';

/// Compact EN / हिन्दी switch for dashboard app bars.
class AppLanguageToggle extends StatelessWidget {
  const AppLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppLocaleController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isHindi = controller.isHindi;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          child: Tooltip(
            message: isHindi ? 'Switch to English' : 'हिंदी में बदलें',
            child: Semantics(
              button: true,
              label: isHindi
                  ? 'Switch language to English'
                  : 'भाषा हिंदी में बदलें',
              child: Material(
                color: AppTheme.softNavy,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: controller.toggleLanguage,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 50,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          size: 15,
                          color: AppTheme.navyBlue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isHindi ? 'हि' : 'EN',
                          style: const TextStyle(
                            color: AppTheme.navyBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

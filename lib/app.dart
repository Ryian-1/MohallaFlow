import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_locale_controller.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class MohallaFlowApp extends StatelessWidget {
  const MohallaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = AppLocaleController.instance;
    return AnimatedBuilder(
      animation: language,
      builder: (context, _) {
        return MaterialApp(
          title: 'MohallaFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          scrollBehavior: const MohallaFlowScrollBehavior(),
          locale: language.locale,
          supportedLocales: const <Locale>[Locale('en'), Locale('hi')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => AppLocaleScope(
            controller: language,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// MOHALLAFLOW_SCROLL_SUPPORT_V1
/// Allows horizontal/vertical scrolling with touch, mouse, stylus and trackpad.
class MohallaFlowScrollBehavior extends MaterialScrollBehavior {
  const MohallaFlowScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

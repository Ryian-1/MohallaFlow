import 'dart:ui' as ui;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'l10n/app_locale_controller.dart';

// Test bypass is enabled only when explicitly requested.
// Never enable this flag for real phone-number verification.
const bool _useTestPhoneAuth = bool.fromEnvironment(
  'MOHALLAFLOW_USE_TEST_PHONE_AUTH',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocaleController.instance.initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final isMobileFirebaseTarget =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (isMobileFirebaseTarget) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(
      kReleaseMode,
    );

    if (kReleaseMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }

  // Test-only bypass for fictional phone numbers configured
  // in Firebase Console. Disabled by default.
  if (kIsWeb && kDebugMode && _useTestPhoneAuth) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }

  runApp(const MohallaFlowApp());
}

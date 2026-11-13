import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level language preference shared by every MohallaFlow role and page.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();
  static const String _preferenceKey = 'mohallaflow_app_language_v1';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  bool get isHindi => _locale.languageCode == 'hi';

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_preferenceKey);
      if (saved == 'hi') {
        _locale = const Locale('hi');
      } else {
        _locale = const Locale('en');
      }
    } catch (_) {
      _locale = const Locale('en');
    }
  }

  Future<void> toggleLanguage() async {
    _locale = isHindi ? const Locale('en') : const Locale('hi');
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, _locale.languageCode);
    } catch (_) {
      // The in-memory language switch remains usable if local persistence fails.
    }
  }
}

/// Inherited notifier makes every screen, dialog and form rebuild when the
/// language changes, without replacing the Navigator or losing page state.
class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static Locale watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    return scope?.notifier?.locale ?? AppLocaleController.instance.locale;
  }
}

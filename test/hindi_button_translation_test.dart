import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohalla_flow/l10n/app_translations.dart';

void main() {
  const hindi = Locale('hi');

  group('MohallaFlow Hindi button translations', () {
    test('notification banner actions are translated', () {
      expect(AppTranslations.translate('OPEN', hindi), 'खोलें');
      expect(AppTranslations.translate('DISMISS', hindi), 'खारिज करें');
    });

    test('dynamic emergency action labels are translated', () {
      expect(
        AppTranslations.translate('Add emergency contacts', hindi),
        'आपातकालीन संपर्क जोड़ें',
      );
      expect(
        AppTranslations.translate('Add assembly points', hindi),
        'सभा स्थल जोड़ें',
      );
      expect(
        AppTranslations.translate('Add readiness checklist', hindi),
        'तैयारी जाँच-सूची जोड़ें',
      );
      expect(
        AppTranslations.translate('Add incident command log', hindi),
        'घटना कमान लॉग जोड़ें',
      );
      expect(
        AppTranslations.translate('Add emergency drills', hindi),
        'आपातकालीन अभ्यास जोड़ें',
      );
      expect(
        AppTranslations.translate('Add emergency preparedness', hindi),
        'आपातकालीन तैयारी जोड़ें',
      );
    });

    test('dynamic date and time labels preserve their values', () {
      expect(AppTranslations.translate('From 09:30 AM', hindi), 'से 09:30 AM');
      expect(AppTranslations.translate('To 10:30 AM', hindi), 'तक 10:30 AM');
      expect(
        AppTranslations.translate('Expense date: 07/11/2026', hindi),
        'व्यय तिथि: 07/11/2026',
      );
      expect(
        AppTranslations.translate('Due date: 07/11/2026', hindi),
        'देय तिथि: 07/11/2026',
      );
    });

    test('dynamic error prefixes are translated while Firebase codes remain intact', () {
      expect(
        AppTranslations.translate(
          'Unable to save event (permission-denied).',
          hindi,
        ),
        'कार्यक्रम सहेजा नहीं जा सका (permission-denied).',
      );
      expect(
        AppTranslations.translate(
          'Unable to mark all as read: permission-denied',
          hindi,
        ),
        'सभी को पढ़ा हुआ चिह्नित नहीं किया जा सका: permission-denied',
      );
    });

    test('UPI action translates amount instruction and preserves amount', () {
      expect(
        AppTranslations.translate('Pay ₹250.00 using UPI app', hindi),
        'UPI ऐप से ₹250.00 का भुगतान करें',
      );
    });
  });
}

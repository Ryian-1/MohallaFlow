// MOHALLAFLOW_HINDI_FEATURE_MODULE_TITLE_TEST_V1
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohalla_flow/l10n/app_translations.dart';

void main() {
  const hindi = Locale('hi');

  group('MohallaFlow Hindi dashboard feature titles', () {
    test('all ten reported feature titles translate exactly', () {
      expect(
        AppTranslations.translate('Resident Self Service', hindi),
        'निवासी स्व-सेवा',
      );
      expect(
        AppTranslations.translate('Workers & Cleanliness', hindi),
        'कर्मचारी एवं सफ़ाई प्रबंधन',
      );
      expect(AppTranslations.translate('Maintenance SLA', hindi), 'रखरखाव SLA');
      expect(AppTranslations.translate('Announcements', hindi), 'घोषणाएँ');
      expect(AppTranslations.translate('Water Supply', hindi), 'जल आपूर्ति');
      expect(
        AppTranslations.translate('Visitor Management', hindi),
        'आगंतुक प्रबंधन',
      );
      expect(
        AppTranslations.translate('Resident Directory & Community Hub', hindi),
        'निवासी निर्देशिका एवं सामुदायिक केंद्र',
      );
      expect(
        AppTranslations.translate('Facility Bookings', hindi),
        'सुविधा बुकिंग',
      );
      expect(
        AppTranslations.translate('Move In Move Out', hindi),
        'आगमन एवं प्रस्थान प्रबंधन',
      );
      expect(
        AppTranslations.translate('Staff Leave Management', hindi),
        'कर्मचारी अवकाश प्रबंधन',
      );
    });

    test('title lookup is insensitive to capitalization', () {
      expect(
        AppTranslations.translate('resident self service', hindi),
        'निवासी स्व-सेवा',
      );
      expect(
        AppTranslations.translate('WORKERS & CLEANLINESS', hindi),
        'कर्मचारी एवं सफ़ाई प्रबंधन',
      );
      expect(AppTranslations.translate('MAINTENANCE SLA', hindi), 'रखरखाव SLA');
      expect(AppTranslations.translate('ANNOUNCEMENTS', hindi), 'घोषणाएँ');
      expect(AppTranslations.translate('WATER SUPPLY', hindi), 'जल आपूर्ति');
      expect(
        AppTranslations.translate('VISITOR MANAGEMENT', hindi),
        'आगंतुक प्रबंधन',
      );
      expect(
        AppTranslations.translate('RESIDENT DIRECTORY & COMMUNITY HUB', hindi),
        'निवासी निर्देशिका एवं सामुदायिक केंद्र',
      );
      expect(
        AppTranslations.translate('FACILITY BOOKINGS', hindi),
        'सुविधा बुकिंग',
      );
      expect(
        AppTranslations.translate('MOVE IN MOVE OUT', hindi),
        'आगमन एवं प्रस्थान प्रबंधन',
      );
      expect(
        AppTranslations.translate('STAFF LEAVE MANAGEMENT', hindi),
        'कर्मचारी अवकाश प्रबंधन',
      );
    });

    test('hyphenated and related screen-title variants remain localized', () {
      expect(
        AppTranslations.translate('Resident Self-Service', hindi),
        'निवासी स्व-सेवा',
      );
      expect(
        AppTranslations.translate('Resident Self-Service Desk', hindi),
        'निवासी स्व-सेवा केंद्र',
      );
      expect(
        AppTranslations.translate('Maintenance SLA & Escalations', hindi),
        'रखरखाव SLA और एस्केलेशन',
      );
      expect(
        AppTranslations.translate('Notices & Announcements', hindi),
        'सूचनाएँ और घोषणाएँ',
      );
      expect(
        AppTranslations.translate('Water Supply Management', hindi),
        'जल आपूर्ति प्रबंधन',
      );
      expect(
        AppTranslations.translate('Move-In / Move-Out', hindi),
        'आगमन एवं प्रस्थान प्रबंधन',
      );
    });

    test('English locale continues to show the original feature titles', () {
      const english = Locale('en');
      expect(
        AppTranslations.translate('Resident Self Service', english),
        'Resident Self Service',
      );
      expect(
        AppTranslations.translate('Workers & Cleanliness', english),
        'Workers & Cleanliness',
      );
    });
  });
}

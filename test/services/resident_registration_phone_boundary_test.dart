import 'package:flutter_test/flutter_test.dart';
import 'package:mohalla_flow/services/resident_registration_activation_service.dart';

void main() {
  group('Indian mobile number normalization boundaries', () {
    test('accepts the lower and upper valid first-digit boundaries', () {
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '6000000000',
        ),
        '6000000000',
      );
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '9999999999',
        ),
        '9999999999',
      );
    });

    test('strips common phone-number formatting separators', () {
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '+91 (98765) 432-10',
        ),
        '9876543210',
      );
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '91-98765-43210',
        ),
        '9876543210',
      );
    });

    test('accepts a country-code prefix with or without plus sign', () {
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '919876543210',
        ),
        '9876543210',
      );
      expect(
        ResidentRegistrationActivationService.toIndianE164('919876543210'),
        '+919876543210',
      );
    });

    test('rejects numbers outside the accepted ten-digit range', () {
      const invalidNumbers = <String>[
        '987654321',
        '09876543210',
        '98765432100',
        '5999999999',
        '1234567890',
        '+1 2025550100',
        '00919876543210',
        '',
        '   ',
      ];

      for (final input in invalidNumbers) {
        expect(
          ResidentRegistrationActivationService.normalizeIndianMobileNumber(
            input,
          ),
          isNull,
          reason: input,
        );
      }
    });

    test('returns null E.164 output when normalization fails', () {
      expect(
        ResidentRegistrationActivationService.toIndianE164('12345'),
        isNull,
      );
    });
  });
}

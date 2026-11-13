import 'package:flutter_test/flutter_test.dart';
import 'package:mohalla_flow/services/resident_registration_activation_service.dart';

void main() {
  group('Indian resident personal login number', () {
    test('accepts a valid 10-digit mobile number', () {
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '9876543210',
        ),
        '9876543210',
      );
    });

    test('normalizes +91 formatted numbers', () {
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '+91 98765 43210',
        ),
        '9876543210',
      );
      expect(
        ResidentRegistrationActivationService.toIndianE164('+91-98765-43210'),
        '+919876543210',
      );
    });

    test('rejects invalid, foreign and empty numbers', () {
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '1234567890',
        ),
        isNull,
      );
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(
          '+1 2025550100',
        ),
        isNull,
      );
      expect(
        ResidentRegistrationActivationService.normalizeIndianMobileNumber(''),
        isNull,
      );
    });
  });
}

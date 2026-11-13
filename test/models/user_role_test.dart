import 'package:flutter_test/flutter_test.dart';
import 'package:mohalla_flow/models/user_role.dart';

void main() {
  group('UserRole.fromFirestore', () {
    const cases = <(String, UserRole)>[
      ('resident', UserRole.resident),
      ('admin', UserRole.admin),
      ('cleanliness_manager', UserRole.cleanlinessManager),
      ('worker', UserRole.worker),
    ];

    for (final (value, expected) in cases) {
      test('maps "$value" to ${expected.name}', () {
        expect(UserRole.fromFirestore(value), expected);
      });

      test('normalizes case and surrounding whitespace for "$value"', () {
        expect(UserRole.fromFirestore('  ${value.toUpperCase()}  '), expected);
      });
    }

    test('rejects null and non-string values', () {
      const invalidValues = <Object?>[
        null,
        0,
        true,
        <Object?>[],
        <String, Object?>{},
      ];

      for (final value in invalidValues) {
        expect(UserRole.fromFirestore(value), isNull, reason: '$value');
      }
    });

    test('rejects blank, unknown and non-canonical role identifiers', () {
      const invalidValues = <String>[
        '',
        '   ',
        'super_admin',
        'cleanliness-manager',
        'manager',
        'resident_admin',
      ];

      for (final value in invalidValues) {
        expect(UserRole.fromFirestore(value), isNull, reason: value);
      }
    });
  });

  group('ColonyMembership', () {
    test('retains required membership identity and role fields', () {
      const membership = ColonyMembership(
        colonyId: 'colony-a',
        colonyName: 'Maple Residency',
        role: UserRole.admin,
      );

      expect(membership.colonyId, 'colony-a');
      expect(membership.colonyName, 'Maple Residency');
      expect(membership.role, UserRole.admin);
      expect(membership.householdId, isNull);
      expect(membership.blockId, isNull);
      expect(membership.workerId, isNull);
      expect(membership.residentId, isNull);
    });

    test('retains optional role-linked record identifiers', () {
      const membership = ColonyMembership(
        colonyId: 'colony-b',
        colonyName: 'Lake View',
        role: UserRole.worker,
        householdId: 'house-12',
        blockId: 'block-c',
        workerId: 'worker-7',
        residentId: 'resident-9',
      );

      expect(membership.householdId, 'house-12');
      expect(membership.blockId, 'block-c');
      expect(membership.workerId, 'worker-7');
      expect(membership.residentId, 'resident-9');
    });
  });

  group('UserAccessResult', () {
    test('reports membership presence from the supplied membership list', () {
      const noMembership = UserAccessResult(
        status: UserAccessStatus.noActiveMembership,
      );
      const oneMembership = UserAccessResult(
        status: UserAccessStatus.authorized,
        memberships: <ColonyMembership>[
          ColonyMembership(
            colonyId: 'colony-a',
            colonyName: 'Maple Residency',
            role: UserRole.resident,
            residentId: 'resident-1',
          ),
        ],
      );

      expect(noMembership.hasActiveMembership, isFalse);
      expect(oneMembership.hasActiveMembership, isTrue);
    });

    test('requires colony selection only for multiple active memberships', () {
      for (final status in UserAccessStatus.values) {
        final result = UserAccessResult(status: status);
        expect(
          result.requiresColonySelection,
          status == UserAccessStatus.multipleMemberships,
          reason: status.name,
        );
      }
    });

    test(
      'allows colony access only for authorized and multiple-membership states',
      () {
        for (final status in UserAccessStatus.values) {
          final result = UserAccessResult(status: status);
          final expected =
              status == UserAccessStatus.authorized ||
              status == UserAccessStatus.multipleMemberships;

          expect(result.canAccessColony, expected, reason: status.name);
        }
      },
    );

    test('retains profile data and error information', () {
      const result = UserAccessResult(
        status: UserAccessStatus.unavailable,
        profileData: <String, dynamic>{'status': 'active'},
        errorMessage: 'Firestore error (unavailable)',
      );

      expect(result.profileData?['status'], 'active');
      expect(result.errorMessage, 'Firestore error (unavailable)');
    });
  });
}

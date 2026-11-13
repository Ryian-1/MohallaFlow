enum UserRole {
  resident('resident', 'Resident'),
  admin('admin', 'Admin'),
  cleanlinessManager('cleanliness_manager', 'Cleanliness Manager'),
  worker('worker', 'Worker');

  const UserRole(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static UserRole? fromFirestore(Object? value) {
    if (value is! String) return null;

    final normalized = value.trim().toLowerCase();

    for (final role in UserRole.values) {
      if (role.firestoreValue == normalized) {
        return role;
      }
    }

    return null;
  }
}

enum UserAccessStatus {
  unauthenticated,
  userProfileMissing,
  noActiveMembership,
  authorized,
  multipleMemberships,
  unavailable,
}

class ColonyMembership {
  const ColonyMembership({
    required this.colonyId,
    required this.colonyName,
    required this.role,
    this.householdId,
    this.blockId,
    this.workerId,
    this.residentId,
  });

  final String colonyId;
  final String colonyName;
  final UserRole role;
  final String? householdId;
  final String? blockId;
  final String? workerId;
  final String? residentId;
}

class UserAccessResult {
  const UserAccessResult({
    required this.status,
    this.profileData,
    this.memberships = const [],
    this.errorMessage,
  });

  final UserAccessStatus status;
  final Map<String, dynamic>? profileData;
  final List<ColonyMembership> memberships;
  final String? errorMessage;

  bool get hasActiveMembership => memberships.isNotEmpty;

  bool get requiresColonySelection =>
      status == UserAccessStatus.multipleMemberships;

  bool get canAccessColony =>
      status == UserAccessStatus.authorized ||
      status == UserAccessStatus.multipleMemberships;
}

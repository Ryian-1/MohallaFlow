import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';

class UserAccessService {
  UserAccessService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserAccessResult> loadCurrentUserAccess() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const UserAccessResult(status: UserAccessStatus.unauthenticated);
    }

    final String uid = currentUser.uid;

    debugPrint('MohallaFlow access verification started.');

    try {
      // 1. Read the exact user profile document.

      final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
          await _firestore.collection('users').doc(uid).get();

      if (!profileSnapshot.exists) {
        return const UserAccessResult(
          status: UserAccessStatus.userProfileMissing,
          errorMessage: 'User profile not found. Check the users document ID.',
        );
      }

      final Map<String, dynamic> profileData = profileSnapshot.data() ?? {};

      // 2. Verify that the user account is active.

      final String accountStatus = (profileData['status'] as String? ?? '')
          .toLowerCase();

      if (accountStatus != 'active') {
        return UserAccessResult(
          status: UserAccessStatus.noActiveMembership,
          profileData: profileData,
          errorMessage: 'Your MohallaFlow account is not active.',
        );
      }

      // 3. Read the colony IDs from the profile.

      final Object? rawColonyIds = profileData['colonyIds'];

      if (rawColonyIds is! List) {
        return UserAccessResult(
          status: UserAccessStatus.noActiveMembership,
          profileData: profileData,
          errorMessage:
              'The colonyIds field must be an array in your user profile.',
        );
      }

      final Set<String> colonyIds = rawColonyIds
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      if (colonyIds.isEmpty) {
        return UserAccessResult(
          status: UserAccessStatus.noActiveMembership,
          profileData: profileData,
          errorMessage: 'No colony has been assigned to your account.',
        );
      }

      // 4. Read each membership by its exact document path.
      //
      // No collectionGroup query is used.

      final List<ColonyMembership> activeMemberships = [];

      for (final String colonyId in colonyIds) {
        final DocumentSnapshot<Map<String, dynamic>> membershipSnapshot =
            await _firestore
                .collection('colonies')
                .doc(colonyId)
                .collection('members')
                .doc(uid)
                .get();

        if (!membershipSnapshot.exists) {
          continue;
        }

        final Map<String, dynamic>? data = membershipSnapshot.data();

        if (data == null) {
          continue;
        }

        // 5. Validate the member identity.

        if (data['uid'] != uid) {
          debugPrint('Membership UID does not match authenticated UID.');
          continue;
        }

        if (data['colonyId'] != colonyId) {
          debugPrint('Membership colony ID does not match document path.');
          continue;
        }

        // 6. Only active members are permitted.

        final String membershipStatus = (data['status'] as String? ?? '')
            .toLowerCase();

        if (membershipStatus != 'active') {
          debugPrint('Membership is not active.');
          continue;
        }

        // 7. Validate the role.

        final UserRole? role = UserRole.fromFirestore(data['role']);

        if (role == null) {
          debugPrint('Membership contains an invalid role.');
          continue;
        }

        activeMemberships.add(
          ColonyMembership(
            colonyId: colonyId,
            colonyName: data['colonyName'] as String? ?? colonyId,
            role: role,
            householdId: data['householdId'] as String?,
            blockId: data['blockId'] as String?,
            workerId: data['workerId'] as String?,
            residentId: data['residentId'] as String?,
          ),
        );
      }

      debugPrint('Active memberships: ${activeMemberships.length}');

      // 8. Reject accounts without an active membership.

      if (activeMemberships.isEmpty) {
        return UserAccessResult(
          status: UserAccessStatus.noActiveMembership,
          profileData: profileData,
          errorMessage:
              'Your profile exists, but no active colony membership '
              'was found for your account.',
        );
      }

      // 9. Determine the user's access state.

      final UserAccessStatus accessStatus = activeMemberships.length == 1
          ? UserAccessStatus.authorized
          : UserAccessStatus.multipleMemberships;

      return UserAccessResult(
        status: accessStatus,
        profileData: profileData,
        memberships: List.unmodifiable(activeMemberships),
      );
    } on FirebaseException catch (error) {
      debugPrint('FIRESTORE ERROR: ${error.code} - ${error.message}');

      return UserAccessResult(
        status: UserAccessStatus.unavailable,
        errorMessage:
            'Firestore error (${error.code}): '
            '${error.message ?? 'Unable to read colony access records.'}',
      );
    } catch (error, stackTrace) {
      debugPrint('ACCESS CHECK ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      return UserAccessResult(
        status: UserAccessStatus.unavailable,
        errorMessage: 'Access verification failed: $error',
      );
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/cleanliness_screen.dart';
import '../screens/resident_dashboard_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/worker_dashboard_screen.dart';
import '../widgets/app_text.dart';

class ColonyDashboardRouter {
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  static void open({
    required BuildContext context,
    required ColonyMembership membership,
    required Map<String, dynamic>? profileData,
  }) {
    if (!context.mounted) return;

    final Object? rawName = profileData?['displayName'];
    final String? firebaseName = FirebaseAuth.instance.currentUser?.displayName;

    final String accountName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : firebaseName != null && firebaseName.trim().isNotEmpty
        ? firebaseName.trim()
        : membership.role.displayName;

    final NavigatorState navigator = Navigator.of(context);
    late final Widget destination;

    switch (membership.role) {
      case UserRole.admin:
        destination = AdminDashboardScreen(
          colonyId: membership.colonyId,
          colonyName: membership.colonyName,
          adminName: accountName,
        );
        break;

      case UserRole.cleanlinessManager:
        destination = CleanlinessScreen(
          colonyId: membership.colonyId,
          colonyName: membership.colonyName,
          adminName: accountName,
        );
        break;

      case UserRole.worker:
        final String? workerId = membership.workerId;

        if (workerId == null || workerId.trim().isEmpty) {
          _showError(
            context,
            'Your Worker account is not linked to a registered worker '
            'in this colony. Please contact your Colony Admin.',
          );
          return;
        }

        destination = WorkerDashboardScreen(
          colonyId: membership.colonyId,
          colonyName: membership.colonyName,
          workerId: workerId,
          workerName: accountName,
          onSignOut: () async {
            await FirebaseAuth.instance.signOut();

            if (!navigator.mounted) return;

            navigator.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
              (route) => false,
            );
          },
        );
        break;

      case UserRole.resident:
        final String? residentId = membership.residentId;

        if (residentId == null || residentId.trim().isEmpty) {
          _showError(
            context,
            'Your account is not linked to a registered resident '
            'in this colony. Please contact your Colony Admin.',
          );
          return;
        }

        destination = ResidentDashboardScreen(
          colonyId: membership.colonyId,
          colonyName: membership.colonyName,
          residentId: residentId,
          residentName: accountName,
          onSignOut: () async {
            await FirebaseAuth.instance.signOut();
          },
        );
        break;
    }

    // Clear the old dashboard and its nested screens. The Firebase
    // authenticated session remains active during colony switching.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => false,
    );
  }
}

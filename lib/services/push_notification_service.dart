import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/notification_center_screen.dart';
import '../screens/emergency_response_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text.dart';

/// V2 push delivery for MohallaFlow.
///
/// Uses Firebase Installation IDs (FIDs), not the deprecated FCM token API.
/// A FID is stored only under each active membership belonging to the signed-
/// in account. New documents use scalar recipientKey; legacy documents without it retain recipientKeys fallback.
class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Remote push is parked for this build; the in-app notification centre remains.
  static const bool _remotePushEnabled = false;

  static BuildContext? _activeContext;
  static String? _activeColonyId;
  static bool _listenersAttached = false;
  static bool _registrationRequested = false;

  static StreamSubscription<String>? _fidSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

  /// Call once from each authenticated role dashboard's initState.
  static void initializeForMember({
    required BuildContext context,
    required String colonyId,
  }) {
    if (!_remotePushEnabled) {
      debugPrint('MohallaFlow remote push is currently disabled.');
      return;
    }
    _activeContext = context;
    _activeColonyId = colonyId;

    _attachListeners();

    if (!_registrationRequested) {
      _registrationRequested = true;
      unawaited(_requestPermissionAndRegister());
    }
  }

  static void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    // Subscribe before register(); FCM emits the FID through onRegistered.
    _fidSubscription = _messaging.onRegistered.listen(
      (installationId) {
        unawaited(_saveInstallationForActiveMemberships(installationId));
      },
      onError: (Object error) {
        debugPrint('MohallaFlow FID registration error: $error');
      },
    );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundBanner,
      onError: (Object error) {
        debugPrint('MohallaFlow foreground push error: $error');
      },
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openNotificationCentre(message.data)),
      onError: (Object error) {
        debugPrint('MohallaFlow push-open error: $error');
      },
    );
  }

  static Future<void> _requestPermissionAndRegister() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('MohallaFlow push permission was denied by the user.');
        _registrationRequested = false;
        return;
      }

      // Foreground pushes are presented as a MohallaFlow MaterialBanner. This
      // prevents duplicate system + in-app banners on Apple platforms.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // Apple requires an APNs token before FCM registration requests.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (var attempt = 0; attempt < 20; attempt++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint(
            'MohallaFlow is waiting for an APNs token. Push registration '
            'will retry the next time an authenticated dashboard opens.',
          );
          _registrationRequested = false;
          return;
        }
      }

      await _messaging.register();

      // Handles an OS notification tapped while the app was terminated.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        await _openNotificationCentre(initialMessage.data);
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'MohallaFlow push setup failed: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _registrationRequested = false;
    } catch (error, stackTrace) {
      debugPrint('MohallaFlow push setup error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _registrationRequested = false;
    }
  }

  static Future<void> _saveInstallationForActiveMemberships(
    String installationId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        installationId.isEmpty ||
        installationId.contains('/')) {
      return;
    }

    try {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      final profileData = profile.data() ?? <String, dynamic>{};
      if ((profileData['status']?.toString().toLowerCase() ?? '') != 'active') {
        return;
      }
      final rawColonyIds = profileData['colonyIds'];
      final colonyIds = <String>{
        if (rawColonyIds is List)
          ...rawColonyIds.whereType<String>().map((value) => value.trim()),
        if ((_activeColonyId ?? '').trim().isNotEmpty) _activeColonyId!.trim(),
      }..removeWhere((value) => value.isEmpty);

      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      for (final colonyId in colonyIds) {
        final memberRef = _firestore
            .collection('colonies')
            .doc(colonyId)
            .collection('members')
            .doc(user.uid);

        final member = await memberRef.get();
        final memberData = member.data();
        if (!member.exists ||
            memberData == null ||
            memberData['uid'] != user.uid ||
            memberData['colonyId'] != colonyId ||
            memberData['status'] != 'active') {
          continue;
        }

        await memberRef.collection('pushInstallations').doc(installationId).set(
          {
            'fid': installationId,
            'platform': platform,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Unable to save MohallaFlow push installation: '
        '${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('MohallaFlow push installation save error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void _showForegroundBanner(RemoteMessage message) {
    final context = _activeContext;
    if (context == null || !context.mounted) return;

    final title =
        (message.notification?.title ??
                message.data['title']?.toString() ??
                'MohallaFlow notification')
            .trim();
    final body =
        (message.notification?.body ??
                message.data['message']?.toString() ??
                'You have a new colony update.')
            .trim();

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: AppTheme.white,
          leading: const Icon(
            Icons.notifications_active_outlined,
            color: AppTheme.navyBlue,
            size: 24,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                unawaited(_openNotificationCentre(message.data));
              },
              child: const AppText('OPEN'),
            ),
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const AppText('DISMISS'),
            ),
          ],
        ),
      );
  }

  static Future<void> _openNotificationCentre(Map<String, dynamic> data) async {
    final context = _activeContext;
    final user = FirebaseAuth.instance.currentUser;
    final colonyId = data['colonyId']?.toString().trim() ?? '';

    if (context == null ||
        !context.mounted ||
        user == null ||
        colonyId.isEmpty) {
      return;
    }

    try {
      final memberSnapshot = await _firestore
          .collection('colonies')
          .doc(colonyId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!context.mounted || !memberSnapshot.exists) return;

      final member = memberSnapshot.data() ?? <String, dynamic>{};
      if (member['uid'] != user.uid ||
          member['colonyId'] != colonyId ||
          member['status'] != 'active') {
        return;
      }

      final roleKey = member['role']?.toString() ?? '';
      if (roleKey.isEmpty) return;

      final eventType = data['eventType']?.toString() ?? '';
      final sourceCollection = data['sourceCollection']?.toString() ?? '';
      final sourceId = data['sourceId']?.toString().trim() ?? '';

      if (eventType.startsWith('emergency_sos_') &&
          sourceCollection == 'emergencyAlerts' &&
          sourceId.isNotEmpty) {
        final alertSnapshot = await _firestore
            .collection('colonies')
            .doc(colonyId)
            .collection('emergencyAlerts')
            .doc(sourceId)
            .get();

        if (!context.mounted || !alertSnapshot.exists) return;

        final alert = alertSnapshot.data() ?? <String, dynamic>{};
        EmergencyResponseMode? emergencyMode;

        if (roleKey == 'admin') {
          emergencyMode = EmergencyResponseMode.admin;
        } else if (roleKey == 'worker' &&
            alert['assignedResponderUid'] == user.uid) {
          emergencyMode = EmergencyResponseMode.responder;
        } else if (roleKey == 'resident' && alert['createdByUid'] == user.uid) {
          emergencyMode = EmergencyResponseMode.resident;
        }

        if (emergencyMode != null) {
          final currentUserName =
              <String?>[
                    member['name']?.toString(),
                    member['fullName']?.toString(),
                    member['displayName']?.toString(),
                    user.displayName,
                  ]
                  .map((value) => value?.trim() ?? '')
                  .firstWhere(
                    (value) => value.isNotEmpty,
                    orElse: () => roleKey,
                  );

          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => EmergencyResponseScreen(
                colonyId: colonyId,
                colonyName: member['colonyName']?.toString() ?? colonyId,
                mode: emergencyMode!,
                currentUserName: currentUserName,
                residentId: member['residentId']?.toString(),
              ),
            ),
          );
          return;
        }
      }

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationCenterScreen(
            colonyId: colonyId,
            colonyName: member['colonyName']?.toString() ?? colonyId,
            roleKey: roleKey,
            workerId: member['workerId']?.toString(),
          ),
        ),
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Unable to open MohallaFlow notification: '
        '${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Remove this device from every active membership before signing out.
  /// Failures are logged but never prevent the user from signing out.
  static Future<void> unregisterCurrentDevice() async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        final profile = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        final rawColonyIds = profile.data()?['colonyIds'];
        final colonyIds = <String>{
          if (rawColonyIds is List)
            ...rawColonyIds.whereType<String>().map((value) => value.trim()),
          if ((_activeColonyId ?? '').trim().isNotEmpty)
            _activeColonyId!.trim(),
        }..removeWhere((value) => value.isEmpty);

        for (final colonyId in colonyIds) {
          final installations = await _firestore
              .collection('colonies')
              .doc(colonyId)
              .collection('members')
              .doc(user.uid)
              .collection('pushInstallations')
              .get();

          for (final installation in installations.docs) {
            await installation.reference.delete();
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('MohallaFlow push cleanup error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (_remotePushEnabled) {
      try {
        await _messaging.unregister();
      } catch (error, stackTrace) {
        debugPrint('MohallaFlow FCM unregister error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    // Cancel notification listeners when clearing the installation.
    unawaited(_fidSubscription?.cancel());
    _fidSubscription = null;
    unawaited(_foregroundSubscription?.cancel());
    _foregroundSubscription = null;
    unawaited(_openedSubscription?.cancel());
    _openedSubscription = null;
    _listenersAttached = false;
    _activeContext = null;
    _activeColonyId = null;
    _registrationRequested = false;
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../models/notification_event_group.dart';
import '../screens/notification_center_screen.dart';
import 'app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.roleKey,
    this.workerId,
    this.iconColor,
  });

  final String colonyId;
  final String colonyName;
  final String roleKey;
  final String? workerId;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return IconButton(
        tooltip: AppTranslations.translate('Notifications'),
        onPressed: null,
        icon: Icon(Icons.notifications_none_rounded, color: iconColor),
      );
    }

    return StreamBuilder(
      stream: NotificationService.notificationStream(
        colonyId: colonyId,
        roleKey: roleKey,
        userId: userId,
        workerId: workerId,
      ),
      builder: (context, notificationSnapshot) {
        return StreamBuilder(
          stream: NotificationService.readReceiptStream(
            colonyId: colonyId,
            userId: userId,
          ),
          builder: (context, readSnapshot) {
            var unreadCount = 0;

            if (notificationSnapshot.hasData && readSnapshot.hasData) {
              final readIds = readSnapshot.data!.docs
                  .map((document) => document.id)
                  .toSet();
              final groups = NotificationEventGroup.fromDocuments(
                notificationSnapshot.data!.docs.map(
                  (document) => NotificationEventDocument(
                    id: document.id,
                    data: document.data(),
                  ),
                ),
              );
              unreadCount = groups
                  .where((group) => !group.isRead(readIds))
                  .length;
            }

            return IconButton(
              tooltip: unreadCount > 0
                  ? AppTranslations.translate(
                      '$unreadCount unread notifications',
                    )
                  : AppTranslations.translate('Notifications'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationCenterScreen(
                      colonyId: colonyId,
                      colonyName: colonyName,
                      roleKey: roleKey,
                      workerId: workerId,
                    ),
                  ),
                );
              },
              icon: SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: iconColor,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -5,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: AppText(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

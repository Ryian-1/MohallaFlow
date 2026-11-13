import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../models/notification_event_group.dart';
import '../widgets/app_text.dart';
import '../l10n/app_locale_controller.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.roleKey,
    this.workerId,
  });

  final String colonyId;
  final String colonyName;
  final String roleKey;
  final String? workerId;

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'complaint_submitted':
        return 'NEW COMPLAINT';
      case 'complaint_status_changed':
        return 'COMPLAINT UPDATE';
      case 'task_assigned':
        return 'TASK ASSIGNED';
      case 'task_status_changed':
        return 'TASK UPDATE';
      case 'maintenance_job_created':
        return 'MAINTENANCE';
      case 'maintenance_job_updated':
        return 'MAINTENANCE UPDATE';
      case 'announcement_published':
        return 'ANNOUNCEMENT';
      case 'visitor_registered':
        return 'EXPECTED VISITOR';
      case 'visitor_checked_in':
        return 'VISITOR ARRIVAL';
      case 'visitor_checked_out':
        return 'VISITOR DEPARTURE';
      case 'housekeeping_submitted':
        return 'NEW HOUSEKEEPING REQUEST';
      case 'housekeeping_assigned':
        return 'HOUSEKEEPING ASSIGNED';
      case 'housekeeping_updated':
        return 'HOUSEKEEPING UPDATE';
      case 'water_delivery_updated':
        return 'WATER SUPPLY UPDATE';
      case 'bill_issued':
        return 'NEW BILL';
      case 'payment_submitted':
        return 'PAYMENT SUBMITTED';
      case 'payment_verified':
        return 'PAYMENT VERIFIED';
      case 'payment_rejected':
        return 'PAYMENT REJECTED';
      default:
        return eventType.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _dateLabel(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 16);
    }
    return 'Just now';
  }

  Future<void> _openNotification(
    BuildContext context,
    String userId,
    NotificationEventGroup group,
    Set<String> readIds,
  ) async {
    final unreadDocumentIds = group.unreadDocumentIds(readIds);
    if (unreadDocumentIds.isNotEmpty) {
      try {
        await NotificationService.markAllAsRead(
          colonyId: colonyId,
          userId: userId,
          notificationIds: unreadDocumentIds,
        );
      } on FirebaseException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText(
                'Unable to mark notification as read: ${error.message ?? error.code}',
              ),
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    final data = group.representative.data;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          title: AppText(
            data['title'] as String? ?? 'Notification',
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  data['message'] as String? ?? '',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                AppText(
                  'Type: ${_eventLabel(data['eventType'] as String? ?? '')}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  'Received: ${_dateLabel(data['createdAt'])}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                if ((data['sourceId'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  AppText(
                    'Reference: ${data['sourceId']}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const AppText('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Notifications')),
        body: const Center(child: AppText('Please sign in again.')),
      );
    }

    final notificationStream = NotificationService.notificationStream(
      colonyId: colonyId,
      roleKey: roleKey,
      userId: userId,
      workerId: workerId,
    );
    final readStream = NotificationService.readReceiptStream(
      colonyId: colonyId,
      userId: userId,
    );

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            AppText(
              colonyName,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationStream,
        builder: (context, notificationSnapshot) {
          if (notificationSnapshot.hasError) {
            return _messageState(
              'Unable to load notifications.',
              notificationSnapshot.error.toString(),
            );
          }

          if (notificationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }

          final notificationDocuments = notificationSnapshot.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: readStream,
            builder: (context, readSnapshot) {
              if (readSnapshot.hasError) {
                return _messageState(
                  'Unable to load read status.',
                  readSnapshot.error.toString(),
                );
              }

              if (readSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                );
              }

              final readIds = readSnapshot.data!.docs
                  .map((document) => document.id)
                  .toSet();
              final groups = NotificationEventGroup.fromDocuments(
                notificationDocuments.map(
                  (document) => NotificationEventDocument(
                    id: document.id,
                    data: document.data(),
                  ),
                ),
              );
              final sorted = groups.toList()
                ..sort((a, b) {
                  final aDate = a.representative.data['createdAt'];
                  final bDate = b.representative.data['createdAt'];
                  final aMillis = aDate is Timestamp
                      ? aDate.millisecondsSinceEpoch
                      : 0;
                  final bMillis = bDate is Timestamp
                      ? bDate.millisecondsSinceEpoch
                      : 0;
                  return bMillis.compareTo(aMillis);
                });
              final unreadIds = sorted
                  .expand((group) => group.unreadDocumentIds(readIds))
                  .toSet()
                  .toList(growable: false);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryValue('Total', '${sorted.length}'),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: AppTheme.borderGrey,
                        ),
                        Expanded(
                          child: _summaryValue('Unread', '${unreadIds.length}'),
                        ),
                        TextButton(
                          onPressed: unreadIds.isEmpty
                              ? null
                              : () async {
                                  try {
                                    await NotificationService.markAllAsRead(
                                      colonyId: colonyId,
                                      userId: userId,
                                      notificationIds: unreadIds,
                                    );
                                  } on FirebaseException catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: AppText(
                                            'Unable to mark all as read: ${error.message ?? error.code}',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: const AppText('Mark all read'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: sorted.isEmpty
                        ? _messageState(
                            'You are all caught up',
                            'New colony activity and updates will appear here.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: sorted.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final group = sorted[index];
                              final data = group.representative.data;
                              final isRead = group.isRead(readIds);

                              return Material(
                                color: AppTheme.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openNotification(
                                    context,
                                    userId,
                                    group,
                                    readIds,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isRead
                                            ? AppTheme.borderGrey
                                            : AppTheme.secondaryNavy,
                                        width: isRead ? 1 : 1.4,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppTheme.lightGrey,
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.notifications_none_rounded,
                                            color: AppTheme.navyBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: AppText(
                                                      data['title']
                                                              as String? ??
                                                          'Notification',
                                                      style: const TextStyle(
                                                        color:
                                                            AppTheme.textDark,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: AppTheme
                                                                .secondaryNavy,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              AppText(
                                                data['message'] as String? ??
                                                    '',
                                                style: const TextStyle(
                                                  color: AppTheme.textGrey,
                                                  fontSize: 12,
                                                  height: 1.45,
                                                ),
                                              ),
                                              const SizedBox(height: 9),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 5,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  AppText(
                                                    _eventLabel(
                                                      data['eventType']
                                                              as String? ??
                                                          '',
                                                    ),
                                                    style: const TextStyle(
                                                      color: AppTheme
                                                          .secondaryNavy,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                  AppText(
                                                    _dateLabel(
                                                      data['createdAt'],
                                                    ),
                                                    style: const TextStyle(
                                                      color: AppTheme.textGrey,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          value,
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
      ],
    );
  }

  Widget _messageState(String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.textGrey,
              size: 46,
            ),
            const SizedBox(height: 12),
            AppText(
              title,
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared Firestore helpers for MohallaFlow's in-app notification centre.
///
/// V2.0 supports complaint updates, cleanliness task assignment/status events,
/// and maintenance job status changes. The API is intentionally batch-based so
/// each notification is committed atomically with the source record change.
class NotificationService {
  NotificationService._();

  static CollectionReference<Map<String, dynamic>> notifications(
    String colonyId,
  ) {
    return FirebaseFirestore.instance
        .collection('colonies')
        .doc(colonyId)
        .collection('notifications');
  }

  static CollectionReference<Map<String, dynamic>> readReceipts({
    required String colonyId,
    required String userId,
  }) {
    return FirebaseFirestore.instance
        .collection('colonies')
        .doc(colonyId)
        .collection('members')
        .doc(userId)
        .collection('notificationReads');
  }

  static List<String> audienceKeys({
    required String roleKey,
    required String userId,
    String? workerId,
  }) {
    final keys = <String>['role:$roleKey', 'user:$userId'];
    final normalizedWorkerId = workerId?.trim() ?? '';
    if (roleKey == 'worker' && normalizedWorkerId.isNotEmpty) {
      keys.add('worker:$normalizedWorkerId');
    }
    return keys;
  }

  static Query<Map<String, dynamic>> visibleNotifications({
    required String colonyId,
    required String roleKey,
    required String userId,
    String? workerId,
  }) {
    return notifications(colonyId)
        .where(
          'recipientKey',
          whereIn: audienceKeys(
            roleKey: roleKey,
            userId: userId,
            workerId: workerId,
          ),
        )
        .limit(100);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> notificationStream({
    required String colonyId,
    required String roleKey,
    required String userId,
    String? workerId,
  }) {
    return visibleNotifications(
      colonyId: colonyId,
      roleKey: roleKey,
      userId: userId,
      workerId: workerId,
    ).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> readReceiptStream({
    required String colonyId,
    required String userId,
  }) {
    return readReceipts(colonyId: colonyId, userId: userId).snapshots();
  }

  static Future<void> markAsRead({
    required String colonyId,
    required String userId,
    required String notificationId,
  }) async {
    await readReceipts(
      colonyId: colonyId,
      userId: userId,
    ).doc(notificationId).set({'readAt': FieldValue.serverTimestamp()});
  }

  static Future<void> markAllAsRead({
    required String colonyId,
    required String userId,
    required Iterable<String> notificationIds,
  }) async {
    final ids = notificationIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;

    final receipts = readReceipts(colonyId: colonyId, userId: userId);
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.set(receipts.doc(id), {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  /// Adds a validated notification to an existing Firestore batch.
  static void addNotificationToBatch({
    required WriteBatch batch,
    required String colonyId,
    required String title,
    required String message,
    required String eventType,
    required List<String> recipientKeys,
    required String sourceCollection,
    required String sourceId,
    required String createdBy,
  }) {
    final allRecipients = recipientKeys.toSet().toList(growable: false);

    for (final recipientKey in allRecipients) {
      batch.set(
        notifications(colonyId).doc(),
        _notificationData(
          title: title,
          message: message,
          eventType: eventType,
          recipientKeys: allRecipients,
          recipientKey: recipientKey,
          sourceCollection: sourceCollection,
          sourceId: sourceId,
          createdBy: createdBy,
        ),
      );
    }
  }

  /// Adds a notification to the same Firestore transaction as a source update.
  static void addNotificationToTransaction({
    required Transaction transaction,
    required String colonyId,
    required String title,
    required String message,
    required String eventType,
    required List<String> recipientKeys,
    required String sourceCollection,
    required String sourceId,
    required String createdBy,
  }) {
    final allRecipients = recipientKeys.toSet().toList(growable: false);

    for (final recipientKey in allRecipients) {
      transaction.set(
        notifications(colonyId).doc(),
        _notificationData(
          title: title,
          message: message,
          eventType: eventType,
          recipientKeys: allRecipients,
          recipientKey: recipientKey,
          sourceCollection: sourceCollection,
          sourceId: sourceId,
          createdBy: createdBy,
        ),
      );
    }
  }

  static Map<String, dynamic> _notificationData({
    required String title,
    required String message,
    required String eventType,
    required List<String> recipientKeys,
    required String recipientKey,
    required String sourceCollection,
    required String sourceId,
    required String createdBy,
  }) {
    return {
      'title': _truncate(title.trim(), 120),
      'message': _truncate(message.trim(), 500),
      'eventType': eventType,
      'recipientKeys': recipientKeys.toSet().toList(growable: false),
      'recipientKey': recipientKey,
      'sourceCollection': sourceCollection,
      'sourceId': sourceId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static void addResidentComplaintSubmitted({
    required WriteBatch batch,
    required String colonyId,
    required String complaintId,
    required String residentName,
    required String category,
    required String location,
    required String complaintType,
    required String createdBy,
  }) {
    final recipients = <String>['role:admin'];
    if (complaintType == 'cleanliness') {
      recipients.add('role:cleanliness_manager');
    }

    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'New complaint submitted',
      message: '$residentName submitted a $category complaint at $location.',
      eventType: 'complaint_submitted',
      recipientKeys: recipients,
      sourceCollection: 'complaints',
      sourceId: complaintId,
      createdBy: createdBy,
    );
  }

  static void addComplaintStatusChanged({
    required WriteBatch batch,
    required String colonyId,
    required String complaintId,
    required String complaintTitle,
    required String newStatus,
    required String recipientUserId,
    required String createdBy,
  }) {
    if (recipientUserId.trim().isEmpty) return;

    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Complaint status updated',
      message: '"${complaintTitle.trim()}" is now ${_statusLabel(newStatus)}.',
      eventType: 'complaint_status_changed',
      recipientKeys: ['user:$recipientUserId'],
      sourceCollection: 'complaints',
      sourceId: complaintId,
      createdBy: createdBy,
    );
  }

  static void addCleanlinessTaskAssigned({
    required WriteBatch batch,
    required String colonyId,
    required String taskId,
    required String taskTitle,
    required String location,
    required String workerId,
    required String workerName,
    required String createdBy,
  }) {
    if (workerId.trim().isEmpty) return;

    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'New cleanliness task assigned',
      message: '$workerName: $taskTitle at $location.',
      eventType: 'task_assigned',
      recipientKeys: ['worker:$workerId'],
      sourceCollection: 'cleanlinessTasks',
      sourceId: taskId,
      createdBy: createdBy,
    );
  }

  static void addCleanlinessTaskStatusChanged({
    required WriteBatch batch,
    required String colonyId,
    required String taskId,
    required String taskTitle,
    required String workerId,
    required String newStatus,
    required String createdBy,
  }) {
    if (workerId.trim().isEmpty) return;

    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Cleanliness task updated',
      message: '"${taskTitle.trim()}" is now ${_statusLabel(newStatus)}.',
      eventType: 'task_status_changed',
      recipientKeys: ['worker:$workerId'],
      sourceCollection: 'cleanlinessTasks',
      sourceId: taskId,
      createdBy: createdBy,
    );
  }

  static void addMaintenanceJobUpdated({
    required WriteBatch batch,
    required String colonyId,
    required String jobId,
    required String jobTitle,
    required String newStatus,
    required String recipientUserId,
    required String createdBy,
  }) {
    if (recipientUserId.trim().isEmpty) return;

    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Maintenance job updated',
      message: '"${jobTitle.trim()}" is now ${_statusLabel(newStatus)}.',
      eventType: 'maintenance_job_updated',
      recipientKeys: ['user:$recipientUserId'],
      sourceCollection: 'maintenanceJobs',
      sourceId: jobId,
      createdBy: createdBy,
    );
  }

  static void addAnnouncementPublished({
    required WriteBatch batch,
    required String colonyId,
    required String announcementId,
    required String title,
    required String category,
    required String createdBy,
  }) {
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'New colony announcement',
      message: '$category: $title',
      eventType: 'announcement_published',
      recipientKeys: const [
        'role:resident',
        'role:cleanliness_manager',
        'role:worker',
      ],
      sourceCollection: 'announcements',
      sourceId: announcementId,
      createdBy: createdBy,
    );
  }

  static void addVisitorRegistered({
    required WriteBatch batch,
    required String colonyId,
    required String visitorId,
    required String visitorName,
    required String hostName,
    required String createdBy,
  }) {
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Visitor expected',
      message: '$visitorName is expected to visit $hostName.',
      eventType: 'visitor_registered',
      recipientKeys: const ['role:admin'],
      sourceCollection: 'visitors',
      sourceId: visitorId,
      createdBy: createdBy,
    );
  }

  static void addVisitorStatusChanged({
    required WriteBatch batch,
    required String colonyId,
    required String visitorId,
    required String visitorName,
    required String newStatus,
    required String hostUid,
    required String createdBy,
  }) {
    if (hostUid.trim().isEmpty ||
        (newStatus != 'checked_in' && newStatus != 'checked_out')) {
      return;
    }
    final isArrival = newStatus == 'checked_in';
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: isArrival ? 'Visitor has arrived' : 'Visitor has departed',
      message: isArrival
          ? '$visitorName has checked in at the colony gate.'
          : '$visitorName has checked out from the colony gate.',
      eventType: isArrival ? 'visitor_checked_in' : 'visitor_checked_out',
      recipientKeys: ['user:${hostUid.trim()}'],
      sourceCollection: 'visitors',
      sourceId: visitorId,
      createdBy: createdBy,
    );
  }

  static void addHousekeepingSubmitted({
    required WriteBatch batch,
    required String colonyId,
    required String requestId,
    required String serviceType,
    required String location,
    required String residentName,
    required String createdBy,
  }) {
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'New housekeeping request',
      message: '$residentName requested $serviceType at $location.',
      eventType: 'housekeeping_submitted',
      recipientKeys: const ['role:admin'],
      sourceCollection: 'housekeepingRequests',
      sourceId: requestId,
      createdBy: createdBy,
    );
  }

  static void addHousekeepingAssigned({
    required WriteBatch batch,
    required String colonyId,
    required String requestId,
    required String serviceType,
    required String workerId,
    required String residentUid,
    required String createdBy,
  }) {
    final recipients = <String>[];
    if (workerId.trim().isNotEmpty) recipients.add('worker:${workerId.trim()}');
    if (residentUid.trim().isNotEmpty) {
      recipients.add('user:${residentUid.trim()}');
    }
    if (recipients.isEmpty) return;
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Housekeeping request assigned',
      message: '$serviceType has been assigned to a housekeeping worker.',
      eventType: 'housekeeping_assigned',
      recipientKeys: recipients,
      sourceCollection: 'housekeepingRequests',
      sourceId: requestId,
      createdBy: createdBy,
    );
  }

  static void addHousekeepingUpdated({
    required WriteBatch batch,
    required String colonyId,
    required String requestId,
    required String serviceType,
    required String newStatus,
    required String residentUid,
    required String createdBy,
  }) {
    if (residentUid.trim().isEmpty) return;
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Housekeeping request updated',
      message: '$serviceType is now ${_statusLabel(newStatus)}.',
      eventType: 'housekeeping_updated',
      recipientKeys: ['user:${residentUid.trim()}'],
      sourceCollection: 'housekeepingRequests',
      sourceId: requestId,
      createdBy: createdBy,
    );
  }

  static void addWaterDeliveryUpdated({
    required WriteBatch batch,
    required String colonyId,
    required String deliveryId,
    required String location,
    required String newStatus,
    required String createdBy,
  }) {
    final status = _statusLabel(newStatus);
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Water supply update',
      message: 'Tanker delivery for $location is $status.',
      eventType: 'water_delivery_updated',
      recipientKeys: const ['role:resident'],
      sourceCollection: 'waterDeliveries',
      sourceId: deliveryId,
      createdBy: createdBy,
    );
  }

  static void addBillIssued({
    required WriteBatch batch,
    required String colonyId,
    required String billId,
    required String createdBy,
  }) {
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Maintenance bill issued',
      message: 'A maintenance bill has been issued. Open Maintenance Dues to review your household balance.',
      eventType: 'bill_issued',
      recipientKeys: const ['role:resident'],
      sourceCollection: 'maintenanceBills',
      sourceId: billId,
      createdBy: createdBy,
    );
  }

  static void addPaymentSubmitted({
    required WriteBatch batch,
    required String colonyId,
    required String paymentId,
    required String residentName,
    required String createdBy,
  }) {
    addNotificationToBatch(
      batch: batch,
      colonyId: colonyId,
      title: 'Maintenance payment submitted',
      message:
          '$residentName submitted a maintenance payment for verification.',
      eventType: 'payment_submitted',
      recipientKeys: const ['role:admin'],
      sourceCollection: 'maintenancePayments',
      sourceId: paymentId,
      createdBy: createdBy,
    );
  }

  static void addPaymentReviewedToTransaction({
    required Transaction transaction,
    required String colonyId,
    required String paymentId,
    required String residentUid,
    required bool approved,
    required String createdBy,
  }) {
    if (residentUid.trim().isEmpty) return;
    addNotificationToTransaction(
      transaction: transaction,
      colonyId: colonyId,
      title: approved
          ? 'Maintenance payment verified'
          : 'Payment needs attention',
      message: approved
          ? 'Your maintenance payment has been verified by the colony admin.'
          : 'Your maintenance payment was rejected. Open Maintenance Dues to review the reason.',
      eventType: approved ? 'payment_verified' : 'payment_rejected',
      recipientKeys: ['user:${residentUid.trim()}'],
      sourceCollection: 'maintenancePayments',
      sourceId: paymentId,
      createdBy: createdBy,
    );
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  static String _statusLabel(String value) {
    switch (value) {
      case 'submitted':
        return 'Submitted';
      case 'acknowledged':
        return 'Acknowledged';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'completed':
        return 'Completed';
      case 'closed':
        return 'Closed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return value.replaceAll('_', ' ');
    }
  }
}

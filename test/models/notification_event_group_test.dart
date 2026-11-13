import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mohalla_flow/models/notification_event_group.dart';

Map<String, dynamic> eventData({
  Timestamp? createdAt,
  String sourceId = 'task-42',
  String eventType = 'task_assigned',
  String message = 'A task was assigned.',
  List<String> recipientKeys = const [
    'role:worker',
    'user:worker-uid',
    'worker:worker-42',
  ],
}) {
  return {
    'title': 'New cleanliness task',
    'message': message,
    'eventType': eventType,
    'recipientKeys': recipientKeys,
    'recipientKey': recipientKeys.first,
    'sourceCollection': 'cleanlinessTasks',
    'sourceId': sourceId,
    'createdBy': 'admin-uid',
    'createdAt': createdAt ?? Timestamp(1700000000, 1000),
  };
}

void main() {
  group('NotificationEventGroup', () {
    test('groups role, user and worker copies into one event', () {
      final data = eventData();

      final groups = NotificationEventGroup.fromDocuments([
        NotificationEventDocument(
          id: 'a_role',
          data: {...data, 'recipientKey': 'role:worker'},
        ),
        NotificationEventDocument(
          id: 'b_user',
          data: {...data, 'recipientKey': 'user:worker-uid'},
        ),
        NotificationEventDocument(
          id: 'c_worker',
          data: {...data, 'recipientKey': 'worker:worker-42'},
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.documents.map((document) => document.id).toList(), [
        'a_role',
        'b_user',
        'c_worker',
      ]);

      expect(groups.single.isRead({'a_role'}), isFalse);
      expect(groups.single.unreadDocumentIds({'a_role'}).toSet(), {
        'b_user',
        'c_worker',
      });
      expect(groups.single.isRead({'a_role', 'b_user', 'c_worker'}), isTrue);
    });

    test('does not merge separate updates to the same source', () {
      final first = eventData(
        createdAt: Timestamp(1700000000, 1000),
        eventType: 'task_status_changed',
        message: 'Task started.',
      );
      final second = eventData(
        createdAt: Timestamp(1700000001, 1000),
        eventType: 'task_status_changed',
        message: 'Task completed.',
      );

      final groups = NotificationEventGroup.fromDocuments([
        NotificationEventDocument(id: 'first', data: first),
        NotificationEventDocument(id: 'second', data: second),
      ]);

      expect(groups, hasLength(2));
    });

    test('does not merge events with different recipient audiences', () {
      final first = eventData();
      final second = eventData(
        recipientKeys: const ['role:admin', 'user:admin-uid'],
      );

      final groups = NotificationEventGroup.fromDocuments([
        NotificationEventDocument(id: 'first', data: first),
        NotificationEventDocument(id: 'second', data: second),
      ]);

      expect(groups, hasLength(2));
    });

    test('groups SOS recipient copies despite separate timestamps', () {
      final first = eventData(
        createdAt: Timestamp(1700000000, 1000),
        sourceId: 'alert-1',
        eventType: 'emergency_sos_escalated',
        recipientKeys: const ['role:admin', 'user:responder-uid'],
      );
      final second = eventData(
        createdAt: Timestamp(1700000001, 2000),
        sourceId: 'alert-1',
        eventType: 'emergency_sos_escalated',
        recipientKeys: const ['role:admin', 'user:responder-uid'],
      );

      final groups = NotificationEventGroup.fromDocuments([
        NotificationEventDocument(
          id: 'sos_alert-1_escalated_evt_r_aaaaaaaaaaaa',
          data: first,
        ),
        NotificationEventDocument(
          id: 'sos_alert-1_escalated_evt_r_bbbbbbbbbbbb',
          data: second,
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.documents, hasLength(2));
    });

    test('groups migrated copies with their original notification', () {
      final original = {
        ...eventData(
          recipientKeys: const [
            'user:worker-uid',
            'role:worker',
            'worker:worker-42',
          ],
        ),
        'scalarRecipientMigrationVersion': 1,
        'recipientKey': 'role:worker',
      };
      final copy = {
        ...eventData(
          recipientKeys: const [
            'role:worker',
            'user:worker-uid',
            'worker:worker-42',
          ],
        ),
        'scalarRecipientMigrationVersion': 1,
        'migrationClone': true,
        'migrationSourceId': 'legacy-original',
        'pushSuppressed': true,
        'recipientKey': 'worker:worker-42',
      };

      final groups = NotificationEventGroup.fromDocuments([
        NotificationEventDocument(id: 'legacy-original', data: original),
        NotificationEventDocument(id: 'deterministic-copy', data: copy),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.representative.id, 'legacy-original');
    });

    test('keeps documents separate when event identity is ambiguous', () {
      final groups = NotificationEventGroup.fromDocuments([
        const NotificationEventDocument(
          id: 'unknown-a',
          data: {'title': 'Notification'},
        ),
        const NotificationEventDocument(
          id: 'unknown-b',
          data: {'title': 'Notification'},
        ),
      ]);

      expect(groups, hasLength(2));
    });
  });
}

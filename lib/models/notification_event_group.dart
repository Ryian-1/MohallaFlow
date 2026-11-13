import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A notification document represented independently of a Firestore snapshot.
class NotificationEventDocument {
  const NotificationEventDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

/// Recipient-specific documents that represent one logical notification event.
class NotificationEventGroup {
  NotificationEventGroup._(List<NotificationEventDocument> documents)
    : documents = List<NotificationEventDocument>.unmodifiable(
        _ordered(documents),
      );

  final List<NotificationEventDocument> documents;

  NotificationEventDocument get representative => documents.first;

  bool isRead(Set<String> readIds) =>
      documents.every((document) => readIds.contains(document.id));

  List<String> unreadDocumentIds(Set<String> readIds) => documents
      .where((document) => !readIds.contains(document.id))
      .map((document) => document.id)
      .toList(growable: false);

  static final RegExp _sosRecipientSuffix = RegExp(r'_r_[0-9a-f]{12}$');

  static List<NotificationEventGroup> fromDocuments(
    Iterable<NotificationEventDocument> source,
  ) {
    final grouped = <String, List<NotificationEventDocument>>{};

    for (final document in source) {
      final key = _groupKey(document);
      grouped
          .putIfAbsent(key, () => <NotificationEventDocument>[])
          .add(document);
    }

    return List<NotificationEventGroup>.unmodifiable(
      grouped.values.map(NotificationEventGroup._),
    );
  }

  static String _groupKey(NotificationEventDocument document) {
    final data = document.data;

    // Migration copies retain the original notification ID as their source.
    if (data['scalarRecipientMigrationVersion'] == 1) {
      final sourceId = data['migrationClone'] == true
          ? data['migrationSourceId']
          : document.id;

      if (sourceId is String && sourceId.isNotEmpty) {
        return jsonEncode(['migration', sourceId]);
      }
    }

    // SOS fan-out writes use a deterministic recipient suffix. Their writes
    // may have different server timestamps, so use the shared event ID.
    if (document.id.startsWith('sos_')) {
      final match = _sosRecipientSuffix.firstMatch(document.id);
      if (match != null) {
        return jsonEncode(['sos', document.id.substring(0, match.start)]);
      }
    }

    final sourceCollection = data['sourceCollection'];
    final sourceId = data['sourceId'];
    final eventType = data['eventType'];
    final createdAt = data['createdAt'];
    final recipientKeys = data['recipientKeys'];

    if (sourceCollection is String &&
        sourceCollection.isNotEmpty &&
        sourceId is String &&
        sourceId.isNotEmpty &&
        eventType is String &&
        eventType.isNotEmpty &&
        createdAt is Timestamp &&
        recipientKeys is List) {
      final recipients =
          recipientKeys
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (recipients.isNotEmpty) {
        return jsonEncode([
          'event',
          sourceCollection,
          sourceId,
          eventType,
          createdAt.seconds,
          createdAt.nanoseconds,
          data['title'] is String ? data['title'] : '',
          data['message'] is String ? data['message'] : '',
          data['createdBy'] is String ? data['createdBy'] : '',
          recipients,
        ]);
      }
    }

    // Do not merge documents when their event identity is ambiguous.
    return jsonEncode(['document', document.id]);
  }

  static List<NotificationEventDocument> _ordered(
    List<NotificationEventDocument> source,
  ) {
    final documents = List<NotificationEventDocument>.of(source);

    int priority(NotificationEventDocument document) {
      if (document.data['migrationClone'] == true) return 2;
      if (_sosRecipientSuffix.hasMatch(document.id)) return 1;
      return 0;
    }

    documents.sort((a, b) {
      final priorityOrder = priority(a).compareTo(priority(b));
      if (priorityOrder != 0) return priorityOrder;
      return a.id.compareTo(b.id);
    });

    return documents;
  }
}

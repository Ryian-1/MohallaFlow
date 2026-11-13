import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Committee member workspace. The Firestore rules remain the source of truth:
/// hiding a section in this screen is not used as an authorization boundary.
class RwaCommitteeWorkspaceScreen extends StatefulWidget {
  const RwaCommitteeWorkspaceScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.memberName,
  });

  final String colonyId;
  final String colonyName;
  final String memberName;

  @override
  State<RwaCommitteeWorkspaceScreen> createState() =>
      _RwaCommitteeWorkspaceScreenState();
}

class _RwaCommitteeWorkspaceScreenState
    extends State<RwaCommitteeWorkspaceScreen> {
  static const _navy = AppTheme.navyBlue;
  static const _grey = AppTheme.textGrey;
  static const _border = AppTheme.borderGrey;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _records(String name) =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection(name);

  DocumentReference<Map<String, dynamic>> get _grant =>
      _records('rwaCommitteePermissions').doc(_uid);

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

  bool _has(List<dynamic> permissions, String key) =>
      permissions.whereType<String>().contains(key);

  Widget _panel({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: _navy, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AppText(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: AppText(text, style: const TextStyle(color: _grey, fontSize: 12)),
  );

  Future<void> _commitWithAudit({
    DocumentReference<Map<String, dynamic>>? updateRef,
    Map<String, dynamic>? updateData,
    DocumentReference<Map<String, dynamic>>? createRef,
    Map<String, dynamic>? createData,
    required String event,
    required String recordType,
    required String recordId,
    required String summary,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    if (updateRef != null && updateData != null) {
      batch.update(updateRef, updateData);
    }
    if (createRef != null && createData != null) {
      batch.set(createRef, createData);
    }
    batch.set(_records('rwaGovernanceAudit').doc(), {
      'event': event,
      'recordType': recordType,
      'recordId': recordId,
      'summary': summary,
      'createdBy': _uid,
      'createdByName': widget.memberName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _updateComplaintStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final current = (data['status'] ?? 'submitted').toString();
    final choices = switch (current) {
      'submitted' => const ['acknowledged', 'in_progress'],
      'acknowledged' => const ['in_progress'],
      'in_progress' => const ['resolved'],
      _ => const <String>[],
    };
    if (choices.isEmpty) {
      _message('This complaint no longer has a delegated status action.');
      return;
    }

    String next = choices.first;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const AppText('Update complaint status'),
          content: DropdownButtonFormField<String>(
            initialValue: next,
            items: choices
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: AppText(value.replaceAll('_', ' ').toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setLocal(() => next = value);
            },
            decoration: InputDecoration(
              labelText: AppTranslations.translate('New status'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, next),
              child: const AppText('Save update'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    try {
      await _commitWithAudit(
        updateRef: _records('complaints').doc(doc.id),
        updateData: {
          'status': selected,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        event: 'committee_complaint_status_updated',
        recordType: 'complaint',
        recordId: doc.id,
        summary:
            'Updated complaint ${data['title'] ?? doc.id} from $current to $selected',
      );
      _message('Complaint status updated.');
    } catch (error) {
      _message('Unable to update complaint: $error');
    }
  }

  Future<void> _updateMaintenanceStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final current = (data['status'] ?? 'open').toString();
    final choices = switch (current) {
      'open' || 'assigned' => const ['in_progress'],
      'in_progress' => const ['completed'],
      _ => const <String>[],
    };
    if (choices.isEmpty) {
      _message('This job no longer has a delegated status action.');
      return;
    }

    final notes = TextEditingController(
      text: (data['resolutionNotes'] ?? '').toString(),
    );
    String next = choices.first;
    try {
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Update maintenance job'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: next,
                    items: choices
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: AppText(
                              value.replaceAll('_', ' ').toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setLocal(() => next = value);
                    },
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('New status'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Work / resolution notes',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (next == 'completed' && notes.text.trim().length < 5) {
                    _message(
                      'Add at least 5 characters of completion evidence.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, next);
                },
                child: const AppText('Save update'),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return;

      await _commitWithAudit(
        updateRef: _records('maintenanceJobs').doc(doc.id),
        updateData: {
          'status': selected,
          'resolutionNotes': notes.text.trim(),
          'completedAt': selected == 'completed'
              ? FieldValue.serverTimestamp()
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        event: 'committee_maintenance_status_updated',
        recordType: 'maintenance_job',
        recordId: doc.id,
        summary:
            'Updated maintenance job ${data['title'] ?? doc.id} from $current to $selected',
      );
      _message('Maintenance job updated.');
    } catch (error) {
      _message('Unable to update maintenance job: $error');
    } finally {
      notes.dispose();
    }
  }

  Future<void> _createAnnouncementDraft() async {
    final title = TextEditingController();
    final message = TextEditingController();
    String category = 'General';
    String priority = 'normal';
    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Create announcement draft'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Title'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: message,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 3000,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Message'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items:
                          [
                                'General',
                                'Maintenance',
                                'Water Supply',
                                'Security',
                                'Events',
                                'Emergency',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: AppText(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) setLocal(() => category = value);
                      },
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Category'),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      items: ['normal', 'important', 'urgent']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(value.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setLocal(() => priority = value);
                      },
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Priority'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AppText(
                      'This creates a draft only. An Admin must review and publish it.',
                      style: TextStyle(color: _grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty ||
                      message.text.trim().isEmpty) {
                    _message('Enter both a title and message.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const AppText('Save draft'),
              ),
            ],
          ),
        ),
      );
      if (shouldSave != true) return;

      final ref = _records('announcements').doc();
      await _commitWithAudit(
        createRef: ref,
        createData: {
          'title': title.text.trim(),
          'message': message.text.trim(),
          'category': category,
          'priority': priority,
          'status': 'draft',
          'createdBy': _uid,
          'createdByName': widget.memberName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'publishedAt': null,
          'archivedAt': null,
        },
        event: 'committee_announcement_draft_created',
        recordType: 'announcement',
        recordId: ref.id,
        summary: 'Created announcement draft: ${title.text.trim()}',
      );
      _message('Draft submitted for Admin review.');
    } catch (error) {
      _message('Unable to save announcement draft: $error');
    } finally {
      title.dispose();
      message.dispose();
    }
  }

  Widget
  _residentDirectory() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _records('residents').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _empty('Resident directory is unavailable.');
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final docs = [...snapshot.data!.docs]
        ..sort(
          (a, b) => (a.data()['fullName'] ?? '').toString().compareTo(
            (b.data()['fullName'] ?? '').toString(),
          ),
        );
      return _panel(
        title: 'Resident directory · ${docs.length}',
        icon: Icons.people_outline,
        child: docs.isEmpty
            ? _empty('No resident records were found.')
            : Column(
                children: docs.take(60).map((doc) {
                  final data = doc.data();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: AppText(
                      (data['fullName'] ?? 'Resident').toString(),
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      '${data['blockId'] ?? '—'} · ${data['houseNumber'] ?? '—'} · ${data['phoneNumber'] ?? '—'}',
                      style: const TextStyle(color: _grey, fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
      );
    },
  );

  Widget _complaints({
    required bool canUpdate,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _records('complaints').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _empty('Complaints are unavailable.');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final docs = [...snapshot.data!.docs]
        ..sort(
          (a, b) => (_date(b.data()['createdAt'])?.millisecondsSinceEpoch ?? 0)
              .compareTo(
                _date(a.data()['createdAt'])?.millisecondsSinceEpoch ?? 0,
              ),
        );
      return _panel(
        title: 'Colony complaints · ${docs.length}',
        icon: Icons.assignment_outlined,
        child: docs.isEmpty
            ? _empty('No complaints are currently recorded.')
            : Column(
                children: docs.take(40).map((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? 'submitted').toString();
                  return Card(
                    color: AppTheme.lightGrey,
                    elevation: 0,
                    child: ListTile(
                      title: AppText(
                        (data['title'] ?? 'Complaint').toString(),
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: AppText(
                        '${data['category'] ?? '—'} · ${data['location'] ?? '—'}\n${data['submittedByName'] ?? data['reportedByName'] ?? 'Resident'} · ${status.replaceAll('_', ' ').toUpperCase()} · ${(data['priority'] ?? 'normal').toString().toUpperCase()}',
                        style: const TextStyle(color: _grey, fontSize: 10),
                      ),
                      isThreeLine: true,
                      trailing: canUpdate
                          ? IconButton(
                              tooltip: AppTranslations.translate(
                                'Update status',
                              ),
                              onPressed:
                                  [
                                    'submitted',
                                    'acknowledged',
                                    'in_progress',
                                  ].contains(status)
                                  ? () => _updateComplaintStatus(doc)
                                  : null,
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: _navy,
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
      );
    },
  );

  Widget _maintenance({
    required bool canUpdate,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _records('maintenanceJobs').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _empty('Maintenance jobs are unavailable.');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final docs = [...snapshot.data!.docs]
        ..sort(
          (a, b) => (_date(b.data()['createdAt'])?.millisecondsSinceEpoch ?? 0)
              .compareTo(
                _date(a.data()['createdAt'])?.millisecondsSinceEpoch ?? 0,
              ),
        );
      return _panel(
        title: 'Maintenance jobs · ${docs.length}',
        icon: Icons.handyman_outlined,
        child: docs.isEmpty
            ? _empty('No maintenance jobs are currently recorded.')
            : Column(
                children: docs.take(40).map((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? 'open').toString();
                  return Card(
                    color: AppTheme.lightGrey,
                    elevation: 0,
                    child: ListTile(
                      title: AppText(
                        (data['title'] ?? 'Maintenance job').toString(),
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: AppText(
                        '${data['category'] ?? '—'} · ${data['location'] ?? '—'}\n${status.replaceAll('_', ' ').toUpperCase()} · ${data['vendorName'] ?? 'Vendor not assigned'}',
                        style: const TextStyle(color: _grey, fontSize: 10),
                      ),
                      isThreeLine: true,
                      trailing: canUpdate
                          ? IconButton(
                              tooltip: AppTranslations.translate(
                                'Update work status',
                              ),
                              onPressed:
                                  [
                                    'open',
                                    'assigned',
                                    'in_progress',
                                  ].contains(status)
                                  ? () => _updateMaintenanceStatus(doc)
                                  : null,
                              icon: const Icon(
                                Icons.edit_note_outlined,
                                color: _navy,
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: _navy,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Committee Workspace',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: _grey, fontSize: 10),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _grant.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _empty('Unable to load your committee access.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final data = snapshot.data!.data();
          if (data == null || data['status'] != 'active') {
            return _empty(
              'Your committee access is not active. Contact the colony Admin.',
            );
          }
          final now = DateTime.now();
          final startsAt = _date(data['startsAt']);
          final expiresAt = _date(data['expiresAt']);
          if (startsAt == null ||
              expiresAt == null ||
              now.isBefore(startsAt) ||
              !now.isBefore(expiresAt)) {
            return _empty(
              'Your committee access is outside its authorised term. Contact the colony Admin.',
            );
          }
          final permissions = data['permissions'] is List
              ? data['permissions'] as List
              : const [];
          final sections = <Widget>[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'AUTHORISED COMMITTEE ACCESS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    '${data['committeePosition'] ?? 'Committee Member'} · ${data['committeeMemberName'] ?? widget.memberName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AppText(
                    'Valid until ${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ];
          if (_has(permissions, 'residents.view')) {
            sections.add(_residentDirectory());
          }
          final canViewComplaints = _has(permissions, 'complaints.view');
          final canUpdateComplaints = _has(
            permissions,
            'complaints.update_status',
          );
          final canViewMaintenance = _has(permissions, 'maintenance.view');
          final canUpdateMaintenance = _has(
            permissions,
            'maintenance.update_status',
          );
          if (canViewComplaints || canUpdateComplaints) {
            sections.add(_complaints(canUpdate: canUpdateComplaints));
          }
          if (canViewMaintenance || canUpdateMaintenance) {
            sections.add(_maintenance(canUpdate: canUpdateMaintenance));
          }
          if (_has(permissions, 'announcements.create_draft')) {
            sections.add(
              _panel(
                title: 'Announcements',
                icon: Icons.campaign_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Prepare a colony notice for Admin review. You cannot publish or archive announcements.',
                      style: TextStyle(color: _grey, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _createAnnouncementDraft,
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const AppText('Create announcement draft'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (sections.length == 1) {
            sections.add(
              _panel(
                title: 'No active permissions',
                child: _empty(
                  'Your Admin has not assigned any operational permissions yet.',
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: sections,
          );
        },
      ),
    );
  }
}
